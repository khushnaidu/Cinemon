-- Photo moderation (App Review 1.2; 18 U.S.C. 2258A). Every profile and
-- review photo is checked by the `moderate-image` Edge Function
-- (supabase/functions/moderate-image). The app asks before posting; this
-- file makes the database ask too, for every image written, so nothing
-- skips it.
--
-- Before running, deploy the function and add two vault secrets
-- (Dashboard -> Project Settings -> Vault):
--   moderation_function_url  https://<project-ref>.supabase.co/functions/v1/moderate-image
--   moderation_hook_secret   the same random string as the function's
--                            MODERATION_HOOK_SECRET
-- Without them uploads still work; only this backstop is skipped.
-- Run after 021. Idempotent.

-- ── 1. What was checked, and what happened ───────────────────
create table if not exists public.media_checks (
  bucket      text not null,
  path        text not null,
  owner_id    uuid,
  verdict     text not null check (verdict in ('ok', 'rejected', 'minors')),
  -- Only for refusals: which categories, and the scores.
  categories  jsonb,
  checked_at  timestamptz not null default now(),
  -- For `minors`: when it was reported to NCMEC, and the report number.
  reported_at timestamptz,
  report_id   text,
  primary key (bucket, path)
);
alter table public.media_checks enable row level security;
revoke all on public.media_checks from anon, authenticated;
drop policy if exists "media checks for moderators" on public.media_checks;
create policy "media checks for moderators" on public.media_checks
  for select to authenticated using (public.is_admin());
grant select on public.media_checks to authenticated;

-- ── 2. Where preserved material goes ─────────────────────────
-- Private, and no policies: only the service role (the function, and a
-- moderator in the dashboard) can touch it.
insert into storage.buckets (id, name, public)
values ('quarantine', 'quarantine', false)
on conflict (id) do nothing;

-- ── 3. Taking a refused photo off everything that shows it ───
create or replace function public.unlink_media(bucket_name text, object_path text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  marker text := '/' || bucket_name || '/' || object_path;
begin
  update public.profiles
     set photo_url = null
   where photo_url like '%' || marker || '%';
  update public.activities
     set photo_urls = array(select u from unnest(photo_urls) u
                             where u not like '%' || marker || '%')
   where exists (select 1 from unnest(photo_urls) u
                  where u like '%' || marker || '%');
end $$;

-- Sexual content involving a minor: the account stops at once, pending
-- review and the report.
create or replace function public.suspend_for_media(target uuid)
returns void
language sql security definer set search_path = public
as $$
  update public.profiles
     set suspended_until = now() + interval '100 years'
   where id = target;
$$;

revoke all on function public.unlink_media(text, text) from public, anon, authenticated;
revoke all on function public.suspend_for_media(uuid) from public, anon, authenticated;
grant execute on function public.unlink_media(text, text) to service_role;
grant execute on function public.suspend_for_media(uuid) to service_role;

-- ── 4. The backstop: every image written is checked ──────────
create or replace function public.moderate_new_media()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  fn  text;
  key text;
begin
  if new.bucket_id not in ('avatars', 'review-media')
     or new.name !~* '\.(jpe?g|png|webp|gif|heic|heif)$' then
    return new;
  end if;
  -- A file written over an old one is a new photo: forget the old verdict.
  if tg_op = 'UPDATE' then
    delete from public.media_checks where bucket = new.bucket_id and path = new.name;
  end if;
  begin
    select decrypted_secret into fn
      from vault.decrypted_secrets where name = 'moderation_function_url' limit 1;
    select decrypted_secret into key
      from vault.decrypted_secrets where name = 'moderation_hook_secret' limit 1;
    if fn is not null and key is not null then
      perform net.http_post(
        url     := fn,
        body    := jsonb_build_object('bucket', new.bucket_id, 'path', new.name),
        headers := jsonb_build_object('Content-Type', 'application/json',
                                      'x-hook-secret', key)
      );
    end if;
  exception when others then
    -- Never fail an upload over the backstop; the app's own check still ran.
    null;
  end;
  return new;
end $$;

drop trigger if exists moderate_new_media on storage.objects;
create trigger moderate_new_media
  after insert or update on storage.objects
  for each row execute function public.moderate_new_media();
