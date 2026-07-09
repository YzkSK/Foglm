import { createClient } from "jsr:@supabase/supabase-js@2";
import sharp from "npm:sharp@0.33";
import { jsonResponse } from "../_shared/http.ts";

// 対応する画像形式(仕様書 3.4参照)。それ以外はアップロードを拒否する。
const ALLOWED_CONTENT_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

// ボヤけ版の生成パラメータ(仕様書 3.4/8.1: 投票中は「うっすらとしか見えない状態」にする)。
// 大きく縮小してからぼかすことで、原本のディテールを復元不能にする。
const BLURRED_RESIZE_WIDTH = 40;
const BLURRED_BLUR_SIGMA = 8;

export function isAllowedPhotoType(contentType: string): boolean {
  return contentType in ALLOWED_CONTENT_TYPES;
}

export type ParsedUploadRequest =
  | { ok: true; groupId: string; photo: File }
  | { ok: false; error: string };

export function parseUploadForm(formData: FormData): ParsedUploadRequest {
  const groupId = formData.get("group_id");
  const photo = formData.get("photo");

  if (typeof groupId !== "string" || groupId.length === 0) {
    return { ok: false, error: "invalid_group_id" };
  }
  if (!(photo instanceof File) || photo.size === 0) {
    return { ok: false, error: "invalid_photo" };
  }
  if (!isAllowedPhotoType(photo.type)) {
    return { ok: false, error: "unsupported_media_type" };
  }

  return { ok: true, groupId, photo };
}

interface PostgrestLikeError {
  code?: string | null;
  message?: string | null;
}

// check_photo_daily_limitトリガー(仕様書 5.2.2参照)が発生させる例外を判定する。
// トリガーはPL/pgSQLのraise exceptionで送出するためcode='P0001'固定であり、
// メッセージ先頭の文言でこのトリガー由来かどうかを識別する。
export function isDailyLimitError(error: PostgrestLikeError | null): boolean {
  if (!error) return false;
  return error.code === "P0001" &&
    (error.message ?? "").startsWith("photos: group ");
}

export function buildStoragePaths(
  groupId: string,
  fileId: string,
  extension: string,
): { originalPath: string; blurredPath: string } {
  return {
    originalPath: `${groupId}/${fileId}-original.${extension}`,
    blurredPath: `${groupId}/${fileId}-blurred.jpg`,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "unauthorized" });
  }
  const userId = userData.user.id;

  let formData: FormData;
  try {
    formData = await req.formData();
  } catch {
    return jsonResponse(400, { error: "invalid_request" });
  }

  const parsed = parseUploadForm(formData);
  if (!parsed.ok) {
    return jsonResponse(400, { error: parsed.error });
  }
  const { groupId, photo } = parsed;

  // 現役メンバーのみ撮影可能(仕様書 8.1: RLSと同じis_active_memberで判定)。
  const { data: isMember, error: memberError } = await userClient.rpc(
    "is_active_member",
    { p_group_id: groupId, p_user_id: userId },
  );
  if (memberError) {
    return jsonResponse(500, { error: "unknown" });
  }
  if (!isMember) {
    return jsonResponse(403, { error: "not_a_member" });
  }

  const originalBytes = new Uint8Array(await photo.arrayBuffer());

  let blurredBytes: Uint8Array;
  try {
    blurredBytes = await sharp(originalBytes)
      .resize(BLURRED_RESIZE_WIDTH)
      .blur(BLURRED_BLUR_SIGMA)
      .jpeg()
      .toBuffer();
  } catch {
    return jsonResponse(400, { error: "invalid_photo" });
  }

  // 原本はservice_roleでのみ書き込み可能な非公開バケットへ保存する(仕様書 8.1参照)。
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const fileId = crypto.randomUUID();
  const extension = ALLOWED_CONTENT_TYPES[photo.type];
  const { originalPath, blurredPath } = buildStoragePaths(groupId, fileId, extension);

  const { error: originalUploadError } = await adminClient.storage
    .from("photo-originals")
    .upload(originalPath, originalBytes, { contentType: photo.type });
  if (originalUploadError) {
    return jsonResponse(500, { error: "upload_failed" });
  }

  const { error: blurredUploadError } = await adminClient.storage
    .from("photo-blurred")
    .upload(blurredPath, blurredBytes, { contentType: "image/jpeg" });
  if (blurredUploadError) {
    await adminClient.storage.from("photo-originals").remove([originalPath]);
    return jsonResponse(500, { error: "upload_failed" });
  }

  // taken_date・上限判定(10枚/3枚)・排他制御はcheck_photo_daily_limitトリガーが担う(仕様書 5.2.1/5.2.2参照)。
  const { data: insertedPhoto, error: insertError } = await adminClient
    .from("photos")
    .insert({
      group_id: groupId,
      taken_by: userId,
      taken_at: new Date().toISOString(),
      original_storage_path: originalPath,
      blurred_storage_path: blurredPath,
    })
    .select("id, taken_date")
    .single();

  if (insertError || !insertedPhoto) {
    // 上限到達時はエラーを返し、写真は保存しない(仕様書 5.2.3参照)。
    // 直前にアップロード済みのStorageオブジェクトを削除して不整合を残さない。
    await adminClient.storage.from("photo-originals").remove([originalPath]);
    await adminClient.storage.from("photo-blurred").remove([blurredPath]);

    if (isDailyLimitError(insertError)) {
      return jsonResponse(409, { error: "daily_limit_reached" });
    }
    return jsonResponse(500, { error: "unknown" });
  }

  // その日・そのグループのdaily_votesが未作成の場合のみ作成する(仕様書 6.3参照)。
  const { error: voteUpsertError } = await adminClient
    .from("daily_votes")
    .upsert(
      { group_id: groupId, vote_date: insertedPhoto.taken_date, status: "open" },
      { onConflict: "group_id,vote_date", ignoreDuplicates: true },
    );

  if (voteUpsertError) {
    return jsonResponse(500, { error: "unknown" });
  }

  return jsonResponse(200, {
    success: true,
    photo_id: insertedPhoto.id,
    taken_date: insertedPhoto.taken_date,
    status: "pending_vote",
  });
});
