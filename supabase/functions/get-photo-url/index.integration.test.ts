import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { getPhotoUrl } from "./index.ts";

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(
      `${name} が未設定です。ローカルSupabaseを起動してから実行してください。`,
    );
  }
  return value;
}

function createServiceRoleClient(): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

const TEST_PASSWORD = "Abcdefg1";

Deno.test("getPhotoUrl caches signed URLs per (bucket, path) and reissues near expiry (integration)", async () => {
  const adminClient = createServiceRoleClient();
  const anonKey = requiredEnv("SUPABASE_ANON_KEY");
  const supabaseUrl = requiredEnv("SUPABASE_URL");

  let userId: string | undefined;
  let groupId: string | undefined;
  const blurredPath = `signed-url-cache-test/${crypto.randomUUID()}.jpg`;

  let cleanupError: Error | undefined;

  try {
    const { data: userData, error: userError } = await adminClient.auth.admin.createUser({
      email: `get-photo-url-cache-${crypto.randomUUID()}@example.com`,
      password: TEST_PASSWORD,
      email_confirm: true,
    });
    if (userError || !userData.user) {
      throw new Error(`テストユーザーの作成に失敗しました: ${userError?.message}`);
    }
    userId = userData.user.id;

    const { error: profileError } = await adminClient.from("users").upsert({
      id: userId,
      auth_provider: "email",
      display_name: "Signed URL Cache Tester",
    });
    if (profileError) {
      throw new Error(`public.usersの作成に失敗しました: ${profileError.message}`);
    }

    const { data: group, error: groupError } = await adminClient
      .from("groups")
      .insert({ name: "Signed URL Cache Group", mode: "group", created_by: userId })
      .select("id")
      .single();
    if (groupError || !group) {
      throw new Error(`groupsの作成に失敗しました: ${groupError?.message}`);
    }
    groupId = group.id;

    const { error: memberError } = await adminClient.from("group_members").upsert({
      group_id: groupId,
      user_id: userId,
    });
    if (memberError) {
      throw new Error(`group_membersの作成に失敗しました: ${memberError.message}`);
    }

    const { error: uploadError } = await adminClient.storage
      .from("photo-blurred")
      .upload(blurredPath, new Uint8Array([0, 1, 2, 3]), { contentType: "image/jpeg" });
    if (uploadError) {
      throw new Error(`ボヤけ版のアップロードに失敗しました: ${uploadError.message}`);
    }

    const takenAt = new Date();
    const { data: photo, error: photoError } = await adminClient
      .from("photos")
      .insert({
        group_id: groupId,
        taken_by: userId,
        taken_at: takenAt.toISOString(),
        taken_date: takenAt.toISOString().slice(0, 10),
        original_storage_path: `signed-url-cache-test/${crypto.randomUUID()}-original.jpg`,
        blurred_storage_path: blurredPath,
        status: "pending_vote",
      })
      .select("id")
      .single();
    if (photoError || !photo) {
      throw new Error(`photosの作成に失敗しました: ${photoError?.message}`);
    }
    const photoId = photo.id as string;

    const anonClientForSignIn = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: signInData, error: signInError } = await anonClientForSignIn.auth
      .signInWithPassword({ email: userData.user.email!, password: TEST_PASSWORD });
    if (signInError || !signInData.session) {
      throw new Error(`テストユーザーのサインインに失敗しました: ${signInError?.message}`);
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: {
        headers: { Authorization: `Bearer ${signInData.session.access_token}` },
      },
    });

    const firstCallNow = new Date("2026-07-11T00:00:00.000Z");
    const first = await getPhotoUrl(callerClient, adminClient, photoId, firstCallNow);
    assertEquals(first.status, 200);
    const firstUrl = first.body.url as string;
    assert(firstUrl.length > 0);
    assertEquals(first.body.expires_in, 300);

    // 60秒後(バッファ30秒より内側)の2回目呼び出しは同一URLを再利用するはず
    const secondCallNow = new Date(firstCallNow.getTime() + 60_000);
    const second = await getPhotoUrl(callerClient, adminClient, photoId, secondCallNow);
    assertEquals(second.status, 200);
    assertEquals(second.body.url, firstUrl);
    assertEquals(second.body.expires_in, 240);

    // createSignedUrlのJWTはiatに実時刻(壁時計)の秒を使うため、直前の呼び出しと同一秒内だと
    // 同じ署名トークンが生成されてしまう。再発行されたことを検証できるよう実時間で1秒以上空ける。
    await new Promise((resolve) => setTimeout(resolve, 1100));

    // 有効期限まで残り10秒(バッファ30秒未満)まで進めると再発行されるはず
    const thirdCallNow = new Date(firstCallNow.getTime() + 290_000);
    const third = await getPhotoUrl(callerClient, adminClient, photoId, thirdCallNow);
    assertEquals(third.status, 200);
    assertNotEquals(third.body.url, firstUrl);
    assertEquals(third.body.expires_in, 300);

    // 非メンバー・存在しないphoto_idで404になることを確認(既存挙動の回帰確認)
    const nonexistentPhotoId = crypto.randomUUID();
    const notFound = await getPhotoUrl(callerClient, adminClient, nonexistentPhotoId, firstCallNow);
    assertEquals(notFound.status, 404);
    assertEquals(notFound.body.error, "not_found");
  } finally {
    if (groupId) {
      const { error } = await adminClient.from("groups").delete().eq("id", groupId);
      if (error) {
        cleanupError = new Error(`groupsの後片付けに失敗しました: ${error.message}`);
      }
    }
    await adminClient.from("signed_url_cache").delete().eq("path", blurredPath);
    await adminClient.storage.from("photo-blurred").remove([blurredPath]);
    if (userId) {
      const { error } = await adminClient.auth.admin.deleteUser(userId);
      if (error && !cleanupError) {
        cleanupError = new Error(`テストユーザーの後片付けに失敗しました: ${error.message}`);
      }
    }
  }

  if (cleanupError) {
    throw cleanupError;
  }
});
