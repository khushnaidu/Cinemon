-- The first-run tour shows once per account, on its first sign-in after
-- signing up, not once per phone: a reinstall used to bring it back for
-- everyone. Accounts that exist when this runs have all used the app, so
-- they're marked as having seen it. Run after 024. Idempotent: the backfill
-- only happens the first time, when the column is created.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'profiles'
       and column_name = 'tour_seen_at'
  ) then
    alter table public.profiles add column tour_seen_at timestamptz;
    update public.profiles set tour_seen_at = now();
  end if;
end $$;
