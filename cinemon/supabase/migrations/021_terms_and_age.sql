-- Terms acceptance and the age gate (App Review 1.2 and 5.1.1; COPPA).
--
-- Everyone agrees to the current Terms of Use and Privacy Policy, and
-- confirms their age, before using 35mm. New accounts do it on the sign-up
-- screen, which passes it along in the sign-up metadata; existing accounts,
-- and anyone signing in with Apple or Google, do it on the agree screen,
-- which calls accept_terms(). Changing the Terms means bumping the version
-- in the app (lib/core/config/legal.dart), and everyone agrees again.
--
-- No date of birth is stored: only when the age was confirmed and whether
-- the person was under 18 at the time. Under-13s are stopped in the app
-- before an account exists. Under-18s start private (UK Children's Code:
-- high privacy by default), and can change it.
-- Run after 020. Idempotent.

alter table public.profiles add column if not exists terms_version     text;
alter table public.profiles add column if not exists terms_accepted_at timestamptz;
alter table public.profiles add column if not exists age_confirmed_at  timestamptz;
alter table public.profiles add column if not exists is_minor          boolean not null default false;

-- ── 1. Only the server writes them ───────────────────────────
create or replace function public.guard_terms_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.terms_version, new.terms_accepted_at, new.age_confirmed_at, new.is_minor)
         is distinct from
         (old.terms_version, old.terms_accepted_at, old.age_confirmed_at, old.is_minor)
  then
    raise exception 'terms columns are set by accept_terms()';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_terms on public.profiles;
create trigger profiles_guard_terms
  before update on public.profiles
  for each row execute function public.guard_terms_columns();

-- ── 2. From the sign-up screen ───────────────────────────────
-- The profile row is made by the auth trigger; this fills in what the
-- sign-up screen agreed to, from the account's metadata.
create or replace function public.terms_from_signup()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  meta jsonb;
begin
  select raw_user_meta_data into meta from auth.users where id = new.id;
  if meta ? 'terms_version' then
    new.terms_version := meta ->> 'terms_version';
    new.terms_accepted_at := now();
  end if;
  if coalesce((meta ->> 'age_confirmed')::boolean, false) then
    new.age_confirmed_at := now();
    new.is_minor := coalesce((meta ->> 'minor')::boolean, false);
    if new.is_minor then
      new.is_private := true;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists profiles_terms_from_signup on public.profiles;
create trigger profiles_terms_from_signup
  before insert on public.profiles
  for each row execute function public.terms_from_signup();

-- ── 3. From the agree screen ─────────────────────────────────
-- `minor` is required the first time (the age hasn't been confirmed yet)
-- and ignored after that.
create or replace function public.accept_terms(version text, minor boolean default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  me public.profiles;
begin
  select * into me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'no profile';
  end if;
  if me.age_confirmed_at is null and minor is null then
    raise exception 'age_required';
  end if;

  update public.profiles
     set terms_version     = version,
         terms_accepted_at = now(),
         age_confirmed_at  = coalesce(age_confirmed_at, now()),
         is_minor          = case when age_confirmed_at is null then minor else is_minor end,
         -- Confirming as under 18 for the first time makes the account
         -- private; they can switch it back.
         is_private        = case when age_confirmed_at is null and minor
                                  then true else is_private end
   where id = auth.uid();
end $$;

revoke all on function public.accept_terms(text, boolean) from public, anon;
grant execute on function public.accept_terms(text, boolean) to authenticated;

-- ── 4. Apple's age signal ────────────────────────────────────
-- Where state law requires it (Texas SB2420 now), the app asks Apple's
-- Declared Age Range service and reports the bracket here. Apple's answer
-- is verified, so unlike the self-declared age it can move is_minor either
-- way. Becoming a minor makes the account private.
create or replace function public.record_age_signal(minor boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.profiles
     set is_minor         = minor,
         age_confirmed_at = coalesce(age_confirmed_at, now()),
         is_private       = case when minor and not is_minor then true else is_private end
   where id = auth.uid();
end $$;

revoke all on function public.record_age_signal(boolean) from public, anon;
grant execute on function public.record_age_signal(boolean) to authenticated;
