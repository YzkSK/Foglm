import { createClient } from "jsr:@supabase/supabase-js@2";
import { isValidPassword } from "../_shared/validation.ts";
import { jsonResponse } from "../_shared/http.ts";

interface ResetPasswordBody {
  password?: unknown;
}

Deno.serve(async (req: Request) => {
  let body: ResetPasswordBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "invalid_request" });
  }

  const password = typeof body.password === "string" ? body.password : "";

  if (!isValidPassword(password)) {
    return jsonResponse(400, { error: "weak_password" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // reset_password はメール内リンクを踏んだ後のリカバリーセッション(Authorization)を
  // そのまま利用し、本人自身のセッションでパスワードを更新する(service_role不要)。
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { error } = await userClient.auth.updateUser({ password });

  if (error) {
    return jsonResponse(400, { error: "update_failed" });
  }

  return jsonResponse(200, { success: true });
});
