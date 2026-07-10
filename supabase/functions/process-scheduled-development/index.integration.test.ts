import { assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { processScheduledDevelopment } from "./index.ts";

function createServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY が未設定です。ローカルSupabaseを起動してから実行してください。",
    );
  }
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

const TAKEN_DATE = "2026-01-10";

Deno.test("processScheduledDevelopment develops due photos and aggregates by group, skipping others (integration)", async () => {
  const supabase = createServiceRoleClient();

  const userIds: string[] = [];
  const groupIds: string[] = [];

  async function createTestUser(displayName: string): Promise<string> {
    const { data, error } = await supabase.auth.admin.createUser({
      email: `process-scheduled-development-${crypto.randomUUID()}@example.com`,
      password: "Abcdefg1",
      email_confirm: true,
    });
    if (error || !data.user) {
      throw new Error(`テストユーザーの作成に失敗しました: ${error?.message}`);
    }
    userIds.push(data.user.id);
    const { error: upsertError } = await supabase.from("users").upsert({
      id: data.user.id,
      auth_provider: "email",
      display_name: displayName,
    });
    if (upsertError) {
      throw new Error(`public.usersの作成に失敗しました: ${upsertError.message}`);
    }
    return data.user.id;
  }

  async function createGroup(name: string, createdBy: string): Promise<string> {
    const { data, error } = await supabase
      .from("groups")
      .insert({ name, mode: "group", created_by: createdBy })
      .select("id")
      .single();
    if (error || !data) {
      throw new Error(`groupsの作成に失敗しました: ${error?.message}`);
    }
    groupIds.push(data.id);
    return data.id;
  }

  async function createPhoto(
    groupId: string,
    takenBy: string,
    suffix: string,
    status: string,
    developScheduledAt: string | null,
    developedAt: string | null = null,
  ): Promise<string> {
    const { data, error } = await supabase
      .from("photos")
      .insert({
        group_id: groupId,
        taken_by: takenBy,
        taken_at: `${TAKEN_DATE}T00:00:00.000Z`,
        taken_date: TAKEN_DATE,
        original_storage_path: `original/${suffix}.jpg`,
        blurred_storage_path: `blurred/${suffix}.jpg`,
        status,
        develop_scheduled_at: developScheduledAt,
        developed_at: developedAt,
      })
      .select("id")
      .single();
    if (error || !data) {
      throw new Error(`photosの作成に失敗しました: ${error?.message}`);
    }
    return data.id;
  }

  let cleanupError: Error | undefined;

  try {
    const userA = await createTestUser("Process Dev A");
    const userB = await createTestUser("Process Dev B");

    const groupA = await createGroup("Process Dev Group A", userA);
    const groupB = await createGroup("Process Dev Group B", userB);

    // group A: 2 photos past due -> both developed, aggregated as 2
    const p1 = await createPhoto(
      groupA,
      userA,
      "p1",
      "waiting_random",
      "2025-01-01T00:00:00.000Z",
    );
    const p2 = await createPhoto(
      groupA,
      userA,
      "p2",
      "waiting_random",
      "2025-01-01T00:00:00.000Z",
    );
    // group A: not due yet -> stays waiting_random
    const p3 = await createPhoto(
      groupA,
      userA,
      "p3",
      "waiting_random",
      "2999-01-01T00:00:00.000Z",
    );
    // group B: 1 photo past due -> developed, aggregated as 1
    const p4 = await createPhoto(
      groupB,
      userB,
      "p4",
      "waiting_random",
      "2025-01-01T00:00:00.000Z",
    );
    // group B: already developed (idempotency) -> untouched
    const p5 = await createPhoto(
      groupB,
      userB,
      "p5",
      "developed",
      "2025-01-01T00:00:00.000Z",
      "2025-01-02T00:00:00.000Z",
    );
    // group A: pending_vote, must not be touched even if develop_scheduled_at is past
    const p6 = await createPhoto(
      groupA,
      userA,
      "p6",
      "pending_vote",
      "2025-01-01T00:00:00.000Z",
    );

    const result = await processScheduledDevelopment(supabase);

    const countsByGroup = new Map(
      result.developedGroupCounts.map((entry) => [entry.groupId, entry.developedCount]),
    );
    assertEquals(countsByGroup.get(groupA), 2);
    assertEquals(countsByGroup.get(groupB), 1);

    const { data: photo1 } = await supabase.from("photos").select("status, developed_at").eq(
      "id",
      p1,
    ).single();
    assertEquals(photo1?.status, "developed");
    if (photo1?.developed_at === null) throw new Error("photo1.developed_at should be set");

    const { data: photo2 } = await supabase.from("photos").select("status").eq("id", p2).single();
    assertEquals(photo2?.status, "developed");

    const { data: photo3 } = await supabase.from("photos").select("status").eq("id", p3).single();
    assertEquals(photo3?.status, "waiting_random");

    const { data: photo4 } = await supabase.from("photos").select("status").eq("id", p4).single();
    assertEquals(photo4?.status, "developed");

    const { data: photo5 } = await supabase.from("photos").select("developed_at").eq("id", p5)
      .single();
    assertEquals(photo5?.developed_at, "2025-01-02T00:00:00+00:00");

    const { data: photo6 } = await supabase.from("photos").select("status").eq("id", p6).single();
    assertEquals(photo6?.status, "pending_vote");
  } finally {
    if (groupIds.length > 0) {
      const { error } = await supabase.from("groups").delete().in("id", groupIds);
      if (error) {
        cleanupError = new Error(`groupsの後片付けに失敗しました: ${error.message}`);
      }
    }
    for (const userId of userIds) {
      const { error } = await supabase.auth.admin.deleteUser(userId);
      if (error && !cleanupError) {
        cleanupError = new Error(`テストユーザーの後片付けに失敗しました: ${error.message}`);
      }
    }
  }

  if (cleanupError) {
    throw cleanupError;
  }
});
