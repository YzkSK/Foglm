import { assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { getActiveGroupMemberFcmTokens } from "./notification-targets.ts";

function createServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY が未設定です。ローカルSupabaseを起動してから実行してください。",
    );
  }
  // service_roleクライアントはサーバーサイド用途のため、ブラウザ向けのトークン自動更新・
  // セッション永続化は不要かつテスト実行時のリソースリーク検知の原因になるため無効化する。
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

Deno.test("getActiveGroupMemberFcmTokens returns tokens registered by active members (integration)", async () => {
  const supabase = createServiceRoleClient();

  const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
    email: `integration-test-${crypto.randomUUID()}@example.com`,
    password: "Abcdefg1",
    email_confirm: true,
  });
  if (authError || !authUser.user) {
    throw new Error(`テストユーザーの作成に失敗しました: ${authError?.message}`);
  }
  const userId = authUser.user.id;
  let groupId: string | undefined;
  let groupCleanupError: Error | undefined;

  try {
    // auth.admin.createUser時にon_auth_user_createdトリガー(handle_new_user)がpublic.usersへ
    // 行を自動作成するため、ここではinsertではなくupsertでfcm_tokenを設定する。
    const { error: userUpsertError } = await supabase.from("users").upsert({
      id: userId,
      auth_provider: "email",
      display_name: "Integration Test User",
      fcm_token: "integration-test-token",
    });
    if (userUpsertError) {
      throw new Error(`public.usersの作成に失敗しました: ${userUpsertError.message}`);
    }

    const { data: group, error: groupError } = await supabase
      .from("groups")
      .insert({ name: "Integration Test Group", mode: "group", created_by: userId })
      .select("id")
      .single();
    if (groupError || !group) {
      throw new Error(`groupsの作成に失敗しました: ${groupError?.message}`);
    }
    groupId = group.id;

    const { error: memberError } = await supabase
      .from("group_members")
      .insert({ group_id: group.id, user_id: userId });
    if (memberError) {
      throw new Error(`group_membersの作成に失敗しました: ${memberError.message}`);
    }

    const tokens = await getActiveGroupMemberFcmTokens(supabase, group.id);

    assertEquals(tokens, ["integration-test-token"]);
  } finally {
    if (groupId) {
      const { error: deleteGroupError } = await supabase
        .from("groups")
        .delete()
        .eq("id", groupId);
      if (deleteGroupError) {
        groupCleanupError = new Error(`groupsの後片付けに失敗しました: ${deleteGroupError.message}`);
      }
    }
    const { error: deleteUserError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteUserError && !groupCleanupError) {
      groupCleanupError = new Error(`テストユーザーの後片付けに失敗しました: ${deleteUserError.message}`);
    }
  }

  if (groupCleanupError) {
    throw groupCleanupError;
  }
});
