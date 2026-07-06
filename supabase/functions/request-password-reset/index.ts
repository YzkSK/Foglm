import { createClient } from "jsr:@supabase/supabase-js@2";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmail(email: string): boolean {
  return EMAIL_PATTERN.test(email);
}

interface RequestPasswordResetBody {
  email?: unknown;
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  let body: RequestPasswordResetBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "invalid_request" });
  }

  const email = typeof body.email === "string" ? body.email.trim() : "";

  if (!isValidEmail(email)) {
    return jsonResponse(400, { error: "invalid_email" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const anonClient = createClient(supabaseUrl, anonKey);
  const { error } = await anonClient.auth.resetPasswordForEmail(email);

  if (error) {
    return jsonResponse(500, { error: "unknown" });
  }

  return jsonResponse(200, { success: true });
});
