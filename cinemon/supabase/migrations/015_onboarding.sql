-- ADR 0004 D7: every new account, however it signed up, picks its username in
-- onboarding. Run after 014. Idempotent.

-- ── 1. Who has finished onboarding ────────────────────────────
-- Everyone who exists today chose a username at sign-up, so they count as
-- done. The backfill runs only when the column is first added: rerunning
-- this file mustn't finish anyone's onboarding for them.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'profiles'
       and column_name = 'onboarded_at'
  ) then
    alter table public.profiles add column onboarded_at timestamptz;
    update public.profiles set onboarded_at = created_at;
  end if;
end $$;

-- ── 2. New accounts start with a placeholder, plus whatever the provider
-- told us. Apple and Google (Phase 3) send a name, Google a photo; onboarding
-- prefills from these. The username in the metadata is only sent by builds
-- from before onboarding.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name, photo_url, onboarded_at)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'username',
      'user_' || substr(replace(new.id::text, '-', ''), 1, 10)
    ),
    nullif(trim(coalesce(new.raw_user_meta_data->>'full_name',
                         new.raw_user_meta_data->>'name')), ''),
    nullif(coalesce(new.raw_user_meta_data->>'avatar_url',
                    new.raw_user_meta_data->>'picture'), ''),
    -- An old build picked the username at sign-up, so it has nothing to
    -- onboard.
    case when new.raw_user_meta_data ? 'username' then now() end
  )
  on conflict (id) do nothing;
  return new;
end $$;

-- ── 3. Usernames people choose ────────────────────────────────
-- 3 to 24 of a–z, 0–9, underscore and full stop, not starting or ending with
-- a full stop. Checked only when a username changes: some older ones don't
-- fit, and a check constraint would reject every later edit to those rows.
create or replace function public.guard_username()
returns trigger language plpgsql as $$
begin
  if new.username is distinct from old.username
     and new.username !~ '^[a-z0-9_][a-z0-9_.]{1,22}[a-z0-9_]$' then
    raise exception 'invalid username'
      using errcode = '23514',
            hint = '3 to 24 lowercase letters, numbers, underscores or full stops';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_username on public.profiles;
create trigger profiles_guard_username
  before update of username on public.profiles
  for each row execute function public.guard_username();

-- Whether a username is free. Security definer so it sees accounts the
-- asker has blocked or been blocked by; your own current name counts as free.
create or replace function public.username_available(name text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select not exists (
    select 1 from public.profiles
     where lower(username) = lower(trim(name))
       and id is distinct from auth.uid()
  );
$$;

revoke all on function public.username_available(text) from public, anon;
grant execute on function public.username_available(text) to authenticated;
