import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { closeDailyVote } from "./index.ts";

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

const VOTE_DATE = "2026-01-10";
const TODAY = "2026-01-10";
const FUTURE_VOTE_DATE = "2026-01-11";

Deno.test("closeDailyVote processes majority/tie/zero-vote daily_votes and skips closed/future ones (integration)", async () => {
  const supabase = createServiceRoleClient();

  const userIds: string[] = [];
  const groupIds: string[] = [];

  async function createTestUser(displayName: string): Promise<string> {
    const { data, error } = await supabase.auth.admin.createUser({
      email: `close-daily-vote-${crypto.randomUUID()}@example.com`,
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
    takenDate: string,
    suffix: string,
    status = "pending_vote",
  ): Promise<string> {
    const { data, error } = await supabase
      .from("photos")
      .insert({
        group_id: groupId,
        taken_by: takenBy,
        taken_at: `${takenDate}T00:00:00.000Z`,
        taken_date: takenDate,
        original_storage_path: `original/${suffix}.jpg`,
        blurred_storage_path: `blurred/${suffix}.jpg`,
        status,
      })
      .select("id")
      .single();
    if (error || !data) {
      throw new Error(`photosの作成に失敗しました: ${error?.message}`);
    }
    return data.id;
  }

  async function createDailyVote(
    groupId: string,
    voteDate: string,
    status = "open",
    extra: Record<string, unknown> = {},
  ): Promise<string> {
    const { data, error } = await supabase
      .from("daily_votes")
      .insert({ group_id: groupId, vote_date: voteDate, status, ...extra })
      .select("id")
      .single();
    if (error || !data) {
      throw new Error(`daily_votesの作成に失敗しました: ${error?.message}`);
    }
    return data.id;
  }

  let cleanupError: Error | undefined;

  try {
    const userA = await createTestUser("Close Vote A");
    const userB = await createTestUser("Close Vote B");
    const userC = await createTestUser("Close Vote C");
    const userD = await createTestUser("Close Vote D");
    const userE = await createTestUser("Close Vote E");

    // Scenario 1: majority winner (P1: 2 votes, P2: 1 vote)
    const majorityGroup = await createGroup("Close Vote Majority Group", userA);
    const p1 = await createPhoto(majorityGroup, userA, VOTE_DATE, "p1");
    const p2 = await createPhoto(majorityGroup, userA, VOTE_DATE, "p2");
    const majorityVote = await createDailyVote(majorityGroup, VOTE_DATE);
    const { error: entriesError1 } = await supabase.from("vote_entries").insert([
      { daily_vote_id: majorityVote, user_id: userA, photo_id: p1 },
      { daily_vote_id: majorityVote, user_id: userB, photo_id: p1 },
      { daily_vote_id: majorityVote, user_id: userC, photo_id: p2 },
    ]);
    if (entriesError1) {
      throw new Error(`vote_entriesの作成に失敗しました: ${entriesError1.message}`);
    }

    // Scenario 2: tie (P3: 1 vote, P4: 1 vote)
    const tieGroup = await createGroup("Close Vote Tie Group", userD);
    const p3 = await createPhoto(tieGroup, userD, VOTE_DATE, "p3");
    const p4 = await createPhoto(tieGroup, userD, VOTE_DATE, "p4");
    const tieVote = await createDailyVote(tieGroup, VOTE_DATE);
    const { error: entriesError2 } = await supabase.from("vote_entries").insert([
      { daily_vote_id: tieVote, user_id: userD, photo_id: p3 },
      { daily_vote_id: tieVote, user_id: userE, photo_id: p4 },
    ]);
    if (entriesError2) {
      throw new Error(`vote_entriesの作成に失敗しました: ${entriesError2.message}`);
    }

    // Scenario 3: zero votes (P5 has no votes at all)
    const zeroGroup = await createGroup("Close Vote Zero Votes Group", userA);
    const p5 = await createPhoto(zeroGroup, userA, VOTE_DATE, "p5");
    const zeroVote = await createDailyVote(zeroGroup, VOTE_DATE);

    // Scenario 4: already closed, must stay untouched (idempotency)
    const closedGroup = await createGroup("Close Vote Already Closed Group", userA);
    const p6 = await createPhoto(closedGroup, userA, VOTE_DATE, "p6", "developed");
    const closedVote = await createDailyVote(closedGroup, VOTE_DATE, "closed", {
      winner_photo_id: p6,
      closed_at: new Date().toISOString(),
    });

    // Scenario 5: future vote_date, must not be processed yet
    const futureGroup = await createGroup("Close Vote Future Group", userA);
    await createPhoto(futureGroup, userA, FUTURE_VOTE_DATE, "p7");
    const futureVote = await createDailyVote(futureGroup, FUTURE_VOTE_DATE);

    const result = await closeDailyVote(supabase, TODAY);

    assertEquals(result.processedCount, 3);

    // Scenario 1 assertions
    const { data: photo1 } = await supabase.from("photos").select("status, developed_at").eq(
      "id",
      p1,
    ).single();
    assertEquals(photo1?.status, "developed");
    assert(photo1?.developed_at !== null);

    const { data: photo2 } = await supabase.from("photos").select(
      "status, develop_scheduled_at",
    ).eq("id", p2).single();
    assertEquals(photo2?.status, "waiting_random");
    assert(photo2?.develop_scheduled_at !== null);
    const scheduled2Ms = new Date(photo2!.develop_scheduled_at as string).getTime();
    const takenDateMs = new Date(`${VOTE_DATE}T00:00:00.000Z`).getTime();
    const dayMs = 24 * 60 * 60 * 1000;
    assert(scheduled2Ms >= takenDateMs + 3 * dayMs);
    assert(scheduled2Ms <= takenDateMs + 14 * dayMs);

    const { data: majorityVoteRow } = await supabase.from("daily_votes").select(
      "status, winner_photo_id",
    ).eq("id", majorityVote).single();
    assertEquals(majorityVoteRow?.status, "closed");
    assertEquals(majorityVoteRow?.winner_photo_id, p1);

    // Scenario 2 assertions (tie: exactly one of P3/P4 wins)
    const { data: tiedPhotos } = await supabase.from("photos").select("id, status").in(
      "id",
      [p3, p4],
    );
    const developedCount = (tiedPhotos ?? []).filter((p) => p.status === "developed").length;
    const waitingCount = (tiedPhotos ?? []).filter((p) => p.status === "waiting_random").length;
    assertEquals(developedCount, 1);
    assertEquals(waitingCount, 1);

    const { data: tieVoteRow } = await supabase.from("daily_votes").select(
      "status, winner_photo_id",
    ).eq("id", tieVote).single();
    assertEquals(tieVoteRow?.status, "closed");
    assert(tieVoteRow?.winner_photo_id === p3 || tieVoteRow?.winner_photo_id === p4);

    // Scenario 3 assertions (zero votes: the only photo wins by default)
    const { data: zeroVoteRow } = await supabase.from("daily_votes").select(
      "status, winner_photo_id",
    ).eq("id", zeroVote).single();
    assertEquals(zeroVoteRow?.status, "closed");
    assertEquals(zeroVoteRow?.winner_photo_id, p5);

    const { data: photo5 } = await supabase.from("photos").select("status").eq("id", p5).single();
    assertEquals(photo5?.status, "developed");

    // Scenario 4 assertions (already closed, untouched)
    const { data: closedVoteRow } = await supabase.from("daily_votes").select("status").eq(
      "id",
      closedVote,
    ).single();
    assertEquals(closedVoteRow?.status, "closed");

    // Scenario 5 assertions (future vote_date, not processed)
    const { data: futureVoteRow } = await supabase.from("daily_votes").select("status").eq(
      "id",
      futureVote,
    ).single();
    assertEquals(futureVoteRow?.status, "open");
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
