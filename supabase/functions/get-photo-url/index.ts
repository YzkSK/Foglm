import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { isValidUuid } from "../_shared/validation.ts";
import { jsonResponse } from "../_shared/http.ts";
import { isCachedUrlUsable, remainingSeconds, resolveStorageTarget } from "./logic.ts";

// 署名付きURLの有効期限(秒)。特に原本URLの漏洩リスクを抑えるため短命にする(仕様書8.1参照)。
const SIGNED_URL_EXPIRES_IN_SECONDS = 300;

interface SignedUrlCacheRow {
  signed_url: string;
  expires_at: string;
}

interface GetPhotoUrlResult {
  status: number;
  body: Record<string, unknown>;
}

/**
 * photo_idから対象バケット/パスを解決し、署名付きURLを返す。
 * 同一(bucket, path)への発行済みURLはsigned_url_cacheに残り有効時間つきで保存されており、
 * バッファ(CACHE_REFRESH_BUFFER_SECONDS)を超えて有効な間は再利用する(issue #167)。
 * これにより複数ユーザー・複数インスタンスからの同時アクセスでも同一URLを返せ、CDNの
 * キャッシュヒット率が上がる。
 */
export async function getPhotoUrl(
  callerClient: SupabaseClient,
  adminClient: SupabaseClient,
  photoId: string,
  now: Date = new Date(),
): Promise<GetPhotoUrlResult> {
  // 呼び出し元本人・対象写真のグループの現役メンバーかどうかの確認は、
  // photos_select_active_member ポリシー(RLS)が効くanonクライアント(callerClient)に委ねる。
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return { status: 401, body: { error: "unauthorized" } };
  }

  const { data: photo, error: photoError } = await callerClient
    .from("photos")
    .select("status, original_storage_path, blurred_storage_path")
    .eq("id", photoId)
    .single();
  if (photoError || !photo) {
    return { status: 404, body: { error: "not_found" } };
  }

  const target = resolveStorageTarget(
    photo.status,
    photo.original_storage_path,
    photo.blurred_storage_path,
  );

  const { data: cached, error: cacheReadError } = await adminClient
    .from("signed_url_cache")
    .select("signed_url, expires_at")
    .eq("bucket", target.bucket)
    .eq("path", target.path)
    .maybeSingle();

  if (cacheReadError) {
    console.error("[get-photo-url] signed_url_cache read failed:", cacheReadError);
  }

  if (cached) {
    const cachedRow = cached as SignedUrlCacheRow;
    const expiresAt = new Date(cachedRow.expires_at);
    if (isCachedUrlUsable(expiresAt, now)) {
      return {
        status: 200,
        body: {
          url: cachedRow.signed_url,
          expires_in: remainingSeconds(expiresAt, now),
        },
      };
    }
  }

  // 原本(developed時)はauthenticatedロール向けのSELECTポリシーが存在しないため、
  // 署名付きURLの発行自体はservice_roleクライアントで行う(仕様書8.1参照)。
  const { data: signed, error: signError } = await adminClient.storage
    .from(target.bucket)
    .createSignedUrl(target.path, SIGNED_URL_EXPIRES_IN_SECONDS);
  if (signError || !signed) {
    return { status: 500, body: { error: "signed_url_failed" } };
  }

  const expiresAt = new Date(now.getTime() + SIGNED_URL_EXPIRES_IN_SECONDS * 1000);
  const { error: cacheUpsertError } = await adminClient
    .from("signed_url_cache")
    .upsert(
      {
        bucket: target.bucket,
        path: target.path,
        signed_url: signed.signedUrl,
        expires_at: expiresAt.toISOString(),
      },
      { onConflict: "bucket,path" },
    );
  if (cacheUpsertError) {
    // キャッシュ保存の失敗は致命的ではない(次回リクエストで再発行されるだけ)ためログのみ。
    console.error("[get-photo-url] signed_url_cache upsert failed:", cacheUpsertError);
  }

  return {
    status: 200,
    body: { url: signed.signedUrl, expires_in: SIGNED_URL_EXPIRES_IN_SECONDS },
  };
}

if (import.meta.main) {
  Deno.serve(async (req: Request) => {
    interface GetPhotoUrlBody {
      photo_id?: unknown;
    }

    let body: GetPhotoUrlBody;
    try {
      body = await req.json();
    } catch {
      return jsonResponse(400, { error: "invalid_photo_id" });
    }

    const photoId = typeof body.photo_id === "string" ? body.photo_id : "";
    if (!isValidUuid(photoId)) {
      return jsonResponse(400, { error: "invalid_photo_id" });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (authHeader === "") {
      return jsonResponse(401, { error: "unauthorized" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const result = await getPhotoUrl(callerClient, adminClient, photoId);
    return jsonResponse(result.status, result.body);
  });
}
