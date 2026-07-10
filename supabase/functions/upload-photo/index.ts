import { createClient } from "jsr:@supabase/supabase-js@2";
import sharp from "npm:sharp@0.33.5";
import { isValidUuid } from "../_shared/validation.ts";
import { jsonResponse } from "../_shared/http.ts";
import {
  buildStoragePath,
  extensionForImageType,
  isSupportedImageType,
  mapPhotoInsertError,
  takenDateInAsiaTokyo,
} from "./logic.ts";

// ボヤけ版のサイズ・ぼかし強度。原本を復元不可能な程度まで縮小・ぼかす(仕様書 8.1参照)。
const BLURRED_WIDTH = 32;
const BLURRED_BLUR_SIGMA = 12;

Deno.serve(async (req: Request) => {
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return jsonResponse(400, { error: "invalid_request" });
  }

  const groupId = form.get("group_id");
  const file = form.get("file");

  if (typeof groupId !== "string" || !isValidUuid(groupId)) {
    return jsonResponse(400, { error: "invalid_group_id" });
  }
  if (!(file instanceof File) || !isSupportedImageType(file.type)) {
    return jsonResponse(400, { error: "unsupported_image_type" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (authHeader === "") {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 呼び出し元本人の権限(現役メンバーか等)の確認にはRLSが効くanonクライアントを使う。
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth
    .getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "unauthorized" });
  }
  const userId = userData.user.id;

  const { data: profile, error: profileError } = await callerClient
    .from("users")
    .select("email_verified")
    .eq("id", userId)
    .single();
  if (profileError || !profile) {
    return jsonResponse(401, { error: "unauthorized" });
  }
  if (!profile.email_verified) {
    return jsonResponse(403, { error: "email_not_verified" });
  }

  // groups_select_active_member ポリシーにより、現役メンバーでなければ0件になる(仕様書 8.1参照)。
  const { data: group, error: groupError } = await callerClient
    .from("groups")
    .select("status")
    .eq("id", groupId)
    .single();
  if (groupError || !group) {
    return jsonResponse(403, { error: "not_active_member" });
  }
  if (group.status !== "active") {
    return jsonResponse(403, { error: "group_archived" });
  }

  const originalBytes = new Uint8Array(await file.arrayBuffer());

  let blurredBytes: Uint8Array;
  try {
    blurredBytes = await sharp(originalBytes)
      .resize({ width: BLURRED_WIDTH })
      .blur(BLURRED_BLUR_SIGMA)
      .jpeg({ quality: 60 })
      .toBuffer();
  } catch {
    return jsonResponse(400, { error: "invalid_image" });
  }

  const photoId = crypto.randomUUID();
  // taken_atはクライアント値を信用せず、受信時のサーバー時刻を用いる
  // (レビュー指摘: taken_atを詐称すると1日上限判定を回避できてしまうため)。
  const takenAt = new Date().toISOString();
  const takenDate = takenDateInAsiaTokyo(takenAt);
  const originalPath = buildStoragePath(
    groupId,
    takenDate,
    photoId,
    extensionForImageType(file.type),
  );
  const blurredPath = buildStoragePath(groupId, takenDate, photoId, "jpg");

  // 原本・ボヤけ版の保存、photos行の作成はいずれもservice_role経由でのみ許可されている
  // (authenticatedロール向けのINSERTポリシーが存在しないため。仕様書 8.1参照)。
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { error: originalUploadError } = await adminClient.storage
    .from("photo-originals")
    .upload(originalPath, originalBytes, { contentType: file.type });
  if (originalUploadError) {
    return jsonResponse(500, { error: "upload_failed" });
  }

  const { error: blurredUploadError } = await adminClient.storage
    .from("photo-blurred")
    .upload(blurredPath, blurredBytes, { contentType: "image/jpeg" });
  if (blurredUploadError) {
    await adminClient.storage.from("photo-originals").remove([
      originalPath,
    ]);
    return jsonResponse(500, { error: "upload_failed" });
  }

  const { data: photo, error: insertError } = await adminClient
    .from("photos")
    .insert({
      id: photoId,
      group_id: groupId,
      taken_by: userId,
      taken_at: takenAt,
      original_storage_path: originalPath,
      blurred_storage_path: blurredPath,
    })
    .select("id, taken_date, status")
    .single();

  if (insertError || !photo) {
    // 上限超過等でphotos行が作成できなかった場合、原本・ボヤけ版とも保存しない(仕様書 5.2.3参照)。
    await adminClient.storage.from("photo-originals").remove([
      originalPath,
    ]);
    await adminClient.storage.from("photo-blurred").remove([blurredPath]);
    const mapping = mapPhotoInsertError(insertError?.code);
    return jsonResponse(mapping.status, { error: mapping.error });
  }

  // その日・そのグループのdaily_votesが未作成なら作成する。既に存在する場合は何もしない
  // (UPSERT。仕様書 6.3参照)。失敗しても写真自体は正常に保存済みのため致命的エラーにはしない
  // (次回同日・同グループの撮影時に再度このUPSERTが試行される)。
  const { error: voteUpsertError } = await adminClient
    .from("daily_votes")
    .upsert(
      { group_id: groupId, vote_date: photo.taken_date },
      { onConflict: "group_id,vote_date", ignoreDuplicates: true },
    );
  if (voteUpsertError) {
    console.error("daily_votes upsert failed", voteUpsertError);
  }

  return jsonResponse(201, { photo_id: photo.id, status: photo.status });
});
