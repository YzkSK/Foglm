import { createClient } from "jsr:@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/http.ts";

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // delete_account はログイン中の本人のセッション(Authorization)をそのまま利用し、
  // 本人自身のセッションでdelete_account_data RPCを実行する(service_role不要)。
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();

  if (userError || !userData.user) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const { error: deleteError } = await userClient.rpc("delete_account_data");

  if (deleteError) {
    return jsonResponse(500, { error: "unknown" });
  }

  await userClient.auth.signOut();

  return jsonResponse(200, { success: true });
});
