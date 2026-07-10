import { createClient } from "jsr:@supabase/supabase-js@2";
import { isValidUuid } from "../_shared/validation.ts";
import { jsonResponse } from "../_shared/http.ts";
import { resolveStorageTarget } from "./logic.ts";

// 署名付きURLの有効期限(秒)。特に原本URLの漏洩リスクを抑えるため短命にする(仕様書8.1参照)。
const SIGNED_URL_EXPIRES_IN_SECONDS = 300;

interface GetPhotoUrlBody {
  photo_id?: unknown;
}

Deno.serve(async (req: Request) => {
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

  // 呼び出し元本人・対象写真のグループの現役メンバーかどうかの確認は、
  // photos_select_active_member ポリシー(RLS)が効くanonクライアントに委ねる。
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth
    .getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const { data: photo, error: photoError } = await callerClient
    .from("photos")
    .select("status, original_storage_path, blurred_storage_path")
    .eq("id", photoId)
    .single();
  if (photoError || !photo) {
    return jsonResponse(404, { error: "not_found" });
  }

  const target = resolveStorageTarget(
    photo.status,
    photo.original_storage_path,
    photo.blurred_storage_path,
  );

  // 原本(developed時)はauthenticatedロール向けのSELECTポリシーが存在しないため、
  // 署名付きURLの発行自体はservice_roleクライアントで行う(仕様書8.1参照)。
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: signed, error: signError } = await adminClient.storage
    .from(target.bucket)
    .createSignedUrl(target.path, SIGNED_URL_EXPIRES_IN_SECONDS);
  if (signError || !signed) {
    return jsonResponse(500, { error: "signed_url_failed" });
  }

  return jsonResponse(200, {
    url: signed.signedUrl,
    expires_in: SIGNED_URL_EXPIRES_IN_SECONDS,
  });
});
