-- A suspension stops everything other people would see (Terms: "we may
-- suspend your account"). 007 and 010 covered reviews, comments, reactions,
-- likes and Explore; this adds playlists and the public face of a profile.
-- Suspended accounts can still read, delete their own things, go private,
-- block, report, and delete their account. Run after 018. Idempotent.

-- ── 1. Playlists ─────────────────────────────────────────────
drop policy if exists "lists own insert" on public.lists;
create policy "lists own insert" on public.lists for insert to authenticated
  with check (auth.uid() = user_id and kind = 'playlist'
              and not public.is_suspended(auth.uid()));

drop policy if exists "lists own update" on public.lists;
create policy "lists own update" on public.lists for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));

-- Adding, reordering and removing films. Removing stays allowed: taking
-- things down is never blocked.
drop policy if exists "list items own write" on public.list_items;
drop policy if exists "list items own insert" on public.list_items;
drop policy if exists "list items own update" on public.list_items;
drop policy if exists "list items own delete" on public.list_items;
create policy "list items own insert" on public.list_items for insert to authenticated
  with check (public.owns_list(list_id) and not public.is_suspended(auth.uid()));
create policy "list items own update" on public.list_items for update to authenticated
  using (public.owns_list(list_id))
  with check (public.owns_list(list_id) and not public.is_suspended(auth.uid()));
create policy "list items own delete" on public.list_items for delete to authenticated
  using (public.owns_list(list_id));

-- ── 2. The public face of a profile ──────────────────────────
-- Name, username, bio and photo are frozen while suspended; clearing the
-- bio or photo is still allowed.
create or replace function public.guard_suspended_profile()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon')
     and public.is_suspended(old.id)
     and (
       new.username is distinct from old.username
       or new.display_name is distinct from old.display_name
       or (new.bio is distinct from old.bio and new.bio is not null and new.bio <> '')
       or (new.photo_url is distinct from old.photo_url and new.photo_url is not null)
     )
  then
    raise exception 'account suspended' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_suspended on public.profiles;
create trigger profiles_guard_suspended
  before update on public.profiles
  for each row execute function public.guard_suspended_profile();
