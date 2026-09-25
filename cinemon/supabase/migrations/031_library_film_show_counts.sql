-- The profile header counts films and shows apart (was one library_count).
-- Kept on the profile, like library_count, so a private account's header
-- still shows them to people who can't read its library.

alter table public.profiles
  add column if not exists library_film_count int not null default 0,
  add column if not exists library_show_count int not null default 0;

create or replace function public.sync_library_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles
       set library_count = library_count + 1,
           library_film_count = library_film_count + (new.media_type = 'movie')::int,
           library_show_count = library_show_count + (new.media_type = 'tv')::int
     where id = new.user_id;
  else
    update public.profiles
       set library_count = greatest(library_count - 1, 0),
           library_film_count = greatest(library_film_count - (old.media_type = 'movie')::int, 0),
           library_show_count = greatest(library_show_count - (old.media_type = 'tv')::int, 0)
     where id = old.user_id;
  end if;
  return null;
end $$;

-- Backfill.
update public.profiles p
   set library_film_count = coalesce(t.films, 0),
       library_show_count = coalesce(t.shows, 0)
  from (
    select pr.id,
           count(l.*) filter (where l.media_type = 'movie') as films,
           count(l.*) filter (where l.media_type = 'tv') as shows
      from public.profiles pr
      left join public.library l on l.user_id = pr.id
     group by pr.id
  ) t
 where t.id = p.id
   and (p.library_film_count, p.library_show_count) is distinct from (coalesce(t.films, 0), coalesce(t.shows, 0));
