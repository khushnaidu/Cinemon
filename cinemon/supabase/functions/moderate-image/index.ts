// moderate-image: checks an uploaded photo before anyone else can see it
// (App Review 1.2; migration 022).
//
// Two callers:
//   - the app, right after uploading a profile or review photo and before
//     saving anything that points at it. It may only ask about its own files.
//   - the database, for every image written to `avatars` or `review-media`,
//     so a client that skips the first call is still checked. It signs its
//     calls with MODERATION_HOOK_SECRET.
//
// The photo goes to OpenAI's moderation model (omni-moderation-latest, free
// to use). Sexual content, graphic violence and self-harm are refused: the
// file is deleted and unlinked from the profile or review. Anything flagged
// as sexual content involving a minor is NOT deleted: US law (18 U.S.C.
// 2258A) requires reporting it to NCMEC and preserving it for a year, so it
// is moved to the private `quarantine` bucket, the account is suspended, and
// it waits in media_checks for a moderator (docs/runbooks/moderation.md).
//
// Environment (Dashboard -> Edge Functions -> Secrets):
//   OPENAI_API_KEY           an OpenAI API key (moderation calls are free)
//   MODERATION_HOOK_SECRET   any long random string; the same value goes in
//                            the vault as `moderation_hook_secret`
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are
// provided by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const openaiKey = Deno.env.get("OPENAI_API_KEY");
const hookSecret = Deno.env.get("MODERATION_HOOK_SECRET");

const buckets = new Set(["avatars", "review-media"]);
const images = /\.(jpe?g|png|webp|gif|heic|heif)$/i;

// What's refused. `sexual/minors` is handled separately, above all of these.
const refused = [
  "sexual",
  "violence/graphic",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions",
];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  let bucket: string, path: string;
  try {
    ({ bucket, path } = await req.json());
  } catch {
    return json({ error: "body" }, 400);
  }
  if (!buckets.has(bucket) || typeof path !== "string" || path.includes("..")) {
    return json({ error: "target" }, 400);
  }

  // Who's asking.
  const fromDatabase =
    !!hookSecret && req.headers.get("x-hook-secret") === hookSecret;
  if (!fromDatabase) {
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
    const { data } = await admin.auth.getUser(jwt);
    if (!data.user || !path.startsWith(`${data.user.id}/`)) {
      return json({ error: "forbidden" }, 403);
    }
  }

  // Voice notes and anything else that isn't a photo aren't checked here.
  if (!images.test(path)) return json({ ok: true, verdict: "skipped" });

  // Already checked (the app and the database both ask about each photo).
  const { data: prior } = await admin
    .from("media_checks")
    .select("verdict")
    .eq("bucket", bucket)
    .eq("path", path)
    .maybeSingle();
  if (prior) return json({ ok: prior.verdict === "ok", verdict: prior.verdict });

  if (!openaiKey) return json({ ok: false, verdict: "error" }, 503);

  const { data: signed } = await admin.storage
    .from(bucket)
    .createSignedUrl(path, 120);
  if (!signed) return json({ ok: false, verdict: "missing" }, 404);

  const res = await fetch("https://api.openai.com/v1/moderations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "omni-moderation-latest",
      input: [{ type: "image_url", image_url: { url: signed.signedUrl } }],
    }),
  });
  if (!res.ok) {
    // Not recorded, so the next ask tries again. The app refuses to post a
    // photo it couldn't check.
    return json({ ok: false, verdict: "error" }, 502);
  }
  const result = (await res.json()).results?.[0];
  const categories: Record<string, boolean> = result?.categories ?? {};
  const scores: Record<string, number> = result?.category_scores ?? {};

  const minors = categories["sexual/minors"] === true;
  const hit = refused.filter((c) => categories[c] === true);
  const verdict = minors ? "minors" : hit.length ? "rejected" : "ok";
  const owner = path.split("/")[0];

  if (verdict === "minors") {
    // Preserve, don't destroy: moved out of public reach for the report.
    await admin.storage
      .from(bucket)
      .copy(path, `${bucket}/${path}`, { destinationBucket: "quarantine" });
    await admin.storage.from(bucket).remove([path]);
    await admin.rpc("suspend_for_media", { target: owner });
  } else if (verdict === "rejected") {
    await admin.storage.from(bucket).remove([path]);
  }
  if (verdict !== "ok") {
    await admin.rpc("unlink_media", { bucket_name: bucket, object_path: path });
  }

  await admin.from("media_checks").upsert({
    bucket,
    path,
    owner_id: owner,
    verdict,
    categories: minors || hit.length ? { flagged: minors ? ["sexual/minors"] : hit, scores } : null,
  });

  return json({ ok: verdict === "ok", verdict });
});
