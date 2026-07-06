import { createClient } from "jsr:@supabase/supabase-js@2";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;

export function isValidEmail(email: string): boolean {
  return EMAIL_PATTERN.test(email);
}

export function isValidPassword(password: string): boolean {
  return PASSWORD_PATTERN.test(password);
}

export function localPartOf(email: string): string {
  return email.split("@")[0];
}

interface SignUpRequestBody {
  email?: unknown;
  password?: unknown;
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  let body: SignUpRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "invalid_request" });
  }

  const email = typeof body.email === "string" ? body.email.trim() : "";
  const password = typeof body.password === "string" ? body.password : "";

  if (!isValidEmail(email)) {
    return jsonResponse(400, { error: "invalid_email" });
  }
  if (!isValidPassword(password)) {
    return jsonResponse(400, { error: "weak_password" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: conflictProvider, error: conflictError } = await adminClient
    .rpc("check_sns_email_conflict", { p_email: email });

  if (conflictError) {
    return jsonResponse(500, { error: "unknown" });
  }

  if (conflictProvider) {
    return jsonResponse(409, {
      error: "email_used_by_sns",
      provider: conflictProvider,
    });
  }

  const anonClient = createClient(supabaseUrl, anonKey);
  const { data: signUpData, error: signUpError } = await anonClient.auth
    .signUp({ email, password });

  if (signUpError || !signUpData.user) {
    return jsonResponse(400, { error: "sign_up_failed" });
  }

  const { error: insertError } = await adminClient.from("users").insert({
    id: signUpData.user.id,
    auth_provider: "email",
    email,
    email_verified: false,
    display_name: localPartOf(email),
  });

  if (insertError) {
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(
      signUpData.user.id,
    );

    if (deleteError) {
      console.error(
        `Failed to compensate for public.users insert failure: ` +
          `auth.users row ${signUpData.user.id} is now orphaned. ` +
          `insertError=${JSON.stringify(insertError)}, ` +
          `deleteError=${JSON.stringify(deleteError)}`,
      );
      return jsonResponse(500, { error: "inconsistent_state" });
    }

    return jsonResponse(500, { error: "unknown" });
  }

  return jsonResponse(200, { success: true });
});
