// apple-revoke: keeps Sign in with Apple's token for each account, and
// revokes it when the account is deleted (App Review 5.1.1(v): deleting an
// account that used Sign in with Apple must revoke its token through
// Apple's REST API). Migration 026 holds the tokens.
//
// Called by the app, signed in, with:
//   { action: "store",  code }   right after Sign in with Apple: swaps the
//                                one-time authorization code for a refresh
//                                token and keeps it.
//   { action: "revoke", code? }  just before Delete account: revokes the
//                                kept token, or one from a fresh code for
//                                accounts that signed in before tokens were
//                                kept. Answers { revoked: false, needCode:
//                                true } when it has neither.
//
// Secrets (Dashboard -> Edge Functions -> Secrets):
//   APPLE_KEY_ID        the Sign in with Apple key's ID
//   APPLE_PRIVATE_KEY   the .p8 file's contents
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const TEAM_ID = "L6YHMZPSYT";
const CLIENT_ID = "com.cinemon.app"; // the bundle ID: native sign-in

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

/// Apple's client secret: a short-lived JWT signed with the key.
async function clientSecret(): Promise<string> {
  const pem = (Deno.env.get("APPLE_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
  const key = await importPKCS8(pem, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APPLE_KEY_ID")! })
    .setIssuer(TEAM_ID)
    .setSubject(CLIENT_ID)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt()
    .setExpirationTime("10m")
    .sign(key);
}

async function exchange(code: string): Promise<string | null> {
  const res = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: CLIENT_ID,
      client_secret: await clientSecret(),
      code,
      grant_type: "authorization_code",
    }),
  });
  if (!res.ok) {
    console.error("apple token exchange failed", res.status, await res.text());
    return null;
  }
  const body = await res.json();
  return body.refresh_token ?? null;
}

async function revoke(token: string): Promise<boolean> {
  const res = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: CLIENT_ID,
      client_secret: await clientSecret(),
      token,
      token_type_hint: "refresh_token",
    }),
  });
  if (!res.ok) console.error("apple revoke failed", res.status, await res.text());
  return res.ok;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  const { data } = await admin.auth.getUser(jwt);
  const user = data.user;
  if (!user) return json({ error: "unauthorised" }, 401);

  let body: { action?: string; code?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "body" }, 400);
  }

  if (body.action === "store") {
    if (!body.code) return json({ error: "code" }, 400);
    const token = await exchange(body.code);
    if (!token) return json({ stored: false }, 502);
    await admin.from("apple_tokens").upsert({
      user_id: user.id,
      refresh_token: token,
      updated_at: new Date().toISOString(),
    });
    return json({ stored: true });
  }

  if (body.action === "revoke") {
    const { data: row } = await admin
      .from("apple_tokens")
      .select("refresh_token")
      .eq("user_id", user.id)
      .maybeSingle();
    let token: string | null = row?.refresh_token ?? null;
    if (!token && body.code) token = await exchange(body.code);
    if (!token) return json({ revoked: false, needCode: !body.code });
    const ok = await revoke(token);
    if (ok) await admin.from("apple_tokens").delete().eq("user_id", user.id);
    return json({ revoked: ok }, ok ? 200 : 502);
  }

  return json({ error: "action" }, 400);
});
