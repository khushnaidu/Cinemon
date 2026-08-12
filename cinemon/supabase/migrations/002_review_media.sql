-- ─────────────────────────────────────────────────────────────
-- 002 — REVIEW MEDIA: spoken reviews and photos
-- ─────────────────────────────────────────────────────────────
-- Safe to run on an existing database, and idempotent, so re-running it or
-- running the full schema.sql afterwards both work.
--
-- Everything here is additive: no existing column changes type, so activities
-- written before this migration keep working untouched (a review with no
-- media reads back as a null url and two empty arrays).

-- ── 1. Columns on activities ────────────────────────────────
alter table public.activities
  add column if not exists voice_note_url         text,
  add column if not exists voice_note_duration_ms int   not null default 0,
  -- Amplitude peaks sampled while recording, 0..1, one per slice.
  --
  -- Stored with the row rather than derived on read: drawing the waveform
  -- otherwise means every client that scrolls past the card downloads and
  -- decodes the audio just to find out what shape to draw. real[] rather than
  -- jsonb because it is a fixed-width numeric array and nothing ever queries
  -- into it.
  add column if not exists voice_note_waveform    real[] not null default '{}',
  add column if not exists photo_urls             text[] not null default '{}';

-- A voice note is only meaningful with a duration, and a duration without a
-- url is a half-written row. Ten seconds is the recording cap, with a second
-- of slack for encoder overshoot.
alter table public.activities
  drop constraint if exists activities_voice_note_coherent;
alter table public.activities
  add constraint activities_voice_note_coherent check (
    (voice_note_url is null and voice_note_duration_ms = 0)
    or (voice_note_url is not null
        and voice_note_duration_ms > 0
        and voice_note_duration_ms <= 11000)
  );

-- Four photos is what the stack on the card back can show without the ones
-- underneath becoming invisible.
alter table public.activities
  drop constraint if exists activities_photo_urls_bounded;
alter table public.activities
  add constraint activities_photo_urls_bounded
  check (array_length(photo_urls, 1) is null or array_length(photo_urls, 1) <= 4);

-- ── 2. Storage bucket ───────────────────────────────────────
-- One bucket for both kinds. They share a lifetime — an activity's media dies
-- with the activity — and splitting them would only duplicate the policies.
--
-- Public read, matching `avatars`: these URLs are embedded in feed cards that
-- every friend renders, and signing each one would mean a round trip per card.
insert into storage.buckets (id, name, public)
values ('review-media', 'review-media', true)
on conflict (id) do nothing;

drop policy if exists "review media public read" on storage.objects;
drop policy if exists "review media own write"   on storage.objects;

create policy "review media public read" on storage.objects for select
  using (bucket_id = 'review-media');

-- Same shape as the avatars policy: the first path segment must be the
-- caller's uid, so review-media/<uid>/<activity>/<file> is writable only by
-- its author. Layout is deliberate — deleting an activity's media is a prefix
-- delete, and nothing else can be caught by it.
create policy "review media own write" on storage.objects for all to authenticated
  using (
    bucket_id = 'review-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'review-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 3. Feed view ────────────────────────────────────────────
-- The view selects a.*, so it picks the new columns up — but only once it is
-- rebuilt. A view's output shape is fixed at creation, so without this the
-- columns exist on the table and are silently missing from every feed read.
drop view if exists public.feed_activities;

create view public.feed_activities
with (security_invoker = true) as
select
  a.*,
  p.username,
  p.photo_url                                as user_photo_url,
  coalesce(l.likes, array[]::text[])         as likes,
  coalesce(r.reactions, '{}'::jsonb)         as reactions
from public.activities a
join public.profiles p on p.id = a.user_id
left join lateral (
  select array_agg(al.user_id::text) as likes
  from public.activity_likes al where al.activity_id = a.id
) l on true
left join lateral (
  select jsonb_object_agg(ar.user_id::text, ar.sticker_id) as reactions
  from public.activity_reactions ar where ar.activity_id = a.id
) r on true;
