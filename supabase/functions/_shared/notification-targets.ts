import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** 指定グループの現役メンバー(left_at is null)が登録しているfcm_tokenの一覧を取得する。未登録は除外する。 */
export async function getActiveGroupMemberFcmTokens(
  supabase: SupabaseClient,
  groupId: string,
): Promise<string[]> {
  const { data, error } = await supabase
    .from("group_members")
    .select("users(fcm_token)")
    .eq("group_id", groupId)
    .is("left_at", null)
    .not("users.fcm_token", "is", null);

  if (error) {
    throw new Error(`グループメンバーのfcm_token取得に失敗しました: ${error.message}`);
  }

  return (data ?? [])
    .map((row) => (row as unknown as { users: { fcm_token: string | null } }).users?.fcm_token)
    .filter((token): token is string => typeof token === "string" && token.length > 0);
}
