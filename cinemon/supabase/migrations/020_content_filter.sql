-- Objectionable-content filter (App Review Guideline 1.2: "a method for
-- filtering objectionable material from being posted"). Every place people
-- write text that others can read is checked on the server before it's
-- saved: reviews, comments, Explore posts and replies, playlist titles,
-- descriptions and notes, and profile names, usernames and bios. A match
-- refuses the write with the message `objectionable_content`, which the app
-- turns into a plain explanation.
--
-- The filter aims at slurs, sexual content involving minors, sexual
-- violence and telling people to harm themselves. Ordinary swearing is
-- allowed: films are discussed with it, and Letterboxd allows it too.
-- Words that are also film titles, places or everyday words ("Niger",
-- "I Am Not Your Negro", "Van Dyke", "Nip/Tuck") are left out on purpose;
-- reports catch their misuse.
-- Reports, blocks and the moderation queue (014) handle the rest.
--
-- Terms live in a table nobody but the service role can read, so moderators
-- can add one from the dashboard without a migration:
--   insert into public.moderation_terms (term, anywhere) values ('...', false);
-- Run after 019. Idempotent.

-- ── 1. The terms ─────────────────────────────────────────────
create table if not exists public.moderation_terms (
  term      text primary key,
  -- false: matched as a whole word or phrase ("cum" never matches
  -- "document"). true: matched anywhere, even with the spaces and symbols
  -- taken out, for long unambiguous slurs people try to disguise
  -- ("n.i.g.g.e.r", "xx_slur_xx").
  anywhere  boolean not null default false,
  added_at  timestamptz not null default now()
);
alter table public.moderation_terms enable row level security;

-- Innocent words that happen to contain an "anywhere" term ("snigger").
-- They're skipped by the inside-a-word match only.
create table if not exists public.moderation_allowed_words (
  word text primary key
);
alter table public.moderation_allowed_words enable row level security;
revoke all on public.moderation_allowed_words from anon, authenticated;
insert into public.moderation_allowed_words (word) values
  ('snigger'), ('sniggers'), ('sniggered'), ('sniggering'), ('sniggerer')
on conflict (word) do nothing;
-- No policies: clients can neither read nor change the list.
revoke all on public.moderation_terms from anon, authenticated;

-- ── 2. Normalising text ──────────────────────────────────────
-- Lower case, look-alike characters mapped back to letters ("n1gg3r"),
-- accents dropped, and everything else turned into single spaces.
create or replace function public.moderation_normalise(t text)
returns text language sql immutable as $$
  select btrim(regexp_replace(
           translate(lower(coalesce(t, '')),
                     '0134579@$!|+àáâãäåèéêëìíîïòóôõöùúûüýÿñç',
                     'oieastgasiitaaaaaaeeeeiiiiooooouuuuyync'),
           '[^a-z]+', ' ', 'g'));
$$;

-- A term as a pattern: each letter may be stretched ("niiigger"), but not
-- dropped, so a slur never matches a different word that shares most of
-- its letters.
create or replace function public.moderation_pattern(term text)
returns text language sql immutable as $$
  select regexp_replace(public.moderation_normalise(term), '([a-z])', '\1+', 'g');
$$;

-- The first term the text contains, or null.
--
-- Letters spelled out one at a time ("s l u r", "s.l.u.r") are joined
-- first. Whole-word terms then match between spaces; "anywhere" terms also
-- match inside a word ("xxslurxx"), but never across two real words, so
-- "the bean era" can't become a slur.
create or replace function public.objectionable_term(t text)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare
  words  text[];
  w      text;
  run    text := '';
  joined text := '';
  inside text;
  hit    text;
begin
  if t is null or t = '' then
    return null;
  end if;
  words := string_to_array(public.moderation_normalise(t), ' ');
  -- Three or more single letters in a row are joined up: "n i g g" -> "nigg".
  foreach w in array coalesce(words, '{}') || array[''] loop
    if length(w) = 1 then
      run := run || w;
    else
      if length(run) >= 3 then
        joined := joined || ' ' || run;
      elsif run <> '' then
        joined := joined || ' ' || array_to_string(regexp_split_to_array(run, ''), ' ');
      end if;
      run := '';
      if w <> '' then
        joined := joined || ' ' || w;
      end if;
    end if;
  end loop;
  joined := joined || ' ';
  -- The same, less the allowed words, for matching inside words.
  select ' ' || coalesce(string_agg(x, ' '), '') || ' ' into inside
    from unnest(string_to_array(btrim(joined), ' ')) x
   where x not in (select word from public.moderation_allowed_words);
  select m.term into hit
    from public.moderation_terms m
   where joined ~ (' ' || public.moderation_pattern(m.term) || ' ')
      or (m.anywhere and inside ~ public.moderation_pattern(m.term))
   limit 1;
  return hit;
end $$;

revoke all on function public.objectionable_term(text) from public, anon;
grant execute on function public.objectionable_term(text) to authenticated;

-- ── 3. Checking writes ───────────────────────────────────────
-- One trigger function for every table; its arguments name the columns to
-- check. Only a column that changed is checked, so editing an old review's
-- rating isn't refused over words it was saved with before this existed.
create or replace function public.refuse_objectionable()
returns trigger language plpgsql as $$
declare
  col  text;
  val  text;
  prev text;
begin
  -- Moderators and the dashboard aren't filtered: they may need to fix
  -- something by hand.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  foreach col in array tg_argv loop
    val := to_jsonb(new) ->> col;
    prev := case when tg_op = 'UPDATE' then to_jsonb(old) ->> col end;
    if val is distinct from prev and public.objectionable_term(val) is not null then
      raise exception 'objectionable_content'
        using errcode = '23514',
              hint = 'This includes language that isn''t allowed on 35mm.';
    end if;
  end loop;
  return new;
end $$;

drop trigger if exists filter_activities on public.activities;
create trigger filter_activities before insert or update on public.activities
  for each row execute function public.refuse_objectionable('review_text');

drop trigger if exists filter_comments on public.comments;
create trigger filter_comments before insert or update on public.comments
  for each row execute function public.refuse_objectionable('content');

drop trigger if exists filter_explore_posts on public.explore_posts;
create trigger filter_explore_posts before insert or update on public.explore_posts
  for each row execute function public.refuse_objectionable('headline', 'body');

drop trigger if exists filter_explore_comments on public.explore_comments;
create trigger filter_explore_comments before insert or update on public.explore_comments
  for each row execute function public.refuse_objectionable('content');

drop trigger if exists filter_lists on public.lists;
create trigger filter_lists before insert or update on public.lists
  for each row execute function public.refuse_objectionable('title', 'description');

drop trigger if exists filter_list_items on public.list_items;
create trigger filter_list_items before insert or update on public.list_items
  for each row execute function public.refuse_objectionable('note');

drop trigger if exists filter_profiles on public.profiles;
create trigger filter_profiles before insert or update on public.profiles
  for each row execute function public.refuse_objectionable('username', 'display_name', 'bio');

-- ── 4. Usernames that pretend to be us ───────────────────────
-- Someone called @35mm or @support could pass as staff. Compared after
-- normalising, so "5upport" and "sup.port" are caught; a few words are
-- refused anywhere in the name ("35mm_help", "the_admin").
create or replace function public.username_reserved(username text)
returns boolean language sql immutable as $$
  with n as (
    select replace(public.moderation_normalise(username), ' ', '') as name
  )
  select n.name in (select replace(public.moderation_normalise(x), ' ', '')
                      from unnest(array[
                        'mod', 'mods', 'support', 'help', 'helpdesk', 'team',
                        'security', 'safety', 'trust', 'apple', 'tmdb',
                        'justwatch', 'youtube', 'system', 'root', 'null',
                        'undefined', 'deleted', 'unknown', 'everyone', 'here',
                        'contact', 'privacy', 'legal', 'terms', 'abuse',
                        'report', 'reports', 'noreply', 'appstore',
                        'appreview']) x)
      or n.name ~ (select string_agg(replace(public.moderation_normalise(x), ' ', ''), '|')
                     from unnest(array['35mm', 'admin', 'moderator',
                                       'official', 'staff']) x)
    from n;
$$;

create or replace function public.guard_reserved_username()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon')
     and new.username is distinct from (case when tg_op = 'UPDATE' then old.username end)
     and public.username_reserved(new.username)
  then
    raise exception 'reserved_username'
      using errcode = '23514',
            hint = 'That username is reserved.';
  end if;
  return new;
end $$;

drop trigger if exists profiles_reserved_username on public.profiles;
create trigger profiles_reserved_username before insert or update of username on public.profiles
  for each row execute function public.guard_reserved_username();

-- ── 5. The starting list ─────────────────────────────────────
-- Slurs by identity (race, ethnicity, religion, sexuality, gender identity,
-- disability), sexual content involving minors, sexual violence, and
-- telling someone to kill themselves. Deliberately not swearing.
insert into public.moderation_terms (term, anywhere) values
  -- Racial and ethnic slurs.
  ('nigger', true), ('niggers', true), ('nigga', false), ('niggas', false),
  ('nigguh', true), ('coon', false), ('coons', false), ('jigaboo', true), ('porch monkey', true),
  ('darkie', false), ('darky', false), ('sambo', false),
  ('pickaninny', true), ('tar baby', false), ('spic', false), ('spics', false),
  ('spick', false), ('wetback', true), ('wetbacks', true), ('beaner', true),
  ('beaners', true), ('chink', false), ('chinks', false), ('gook', false),
  ('gooks', false), ('slant eye', false), ('slanteye', true), ('zipperhead', true),
  ('jap', false), ('japs', false), ('kike', true), ('kikes', true),
  ('yid', false), ('hymie', false), ('heeb', false), ('raghead', true),
  ('ragheads', true), ('towelhead', true), ('towelheads', true),
  ('sand nigger', true), ('camel jockey', true), ('paki', false), ('pakis', false),
  ('wog', false), ('wogs', false), ('gyppo', true), ('gypo', false),
  ('redskin', false), ('redskins', false), ('injun', false), ('squaw', false),
  ('abo', false), ('abbo', false), ('coolie', false), ('dago', false),
  ('wop', false), ('kraut', false), ('chinaman', false), ('golliwog', true),
  ('white power', false), ('heil hitler', true), ('sieg heil', true),
  ('gas the jews', true), ('race traitor', false), ('white genocide', false),
  -- Sexuality and gender identity.
  ('faggot', true), ('faggots', true), ('fag', false), ('fags', false),
  ('faggy', false), ('tranny', true),
  ('trannies', true), ('shemale', true), ('she male', false), ('ladyboy', false),
  ('troon', false), ('troons', false), ('poofter', true), ('batty boy', false), ('sodomite', false),
  -- Disability.
  ('retard', false), ('retards', false), ('retarded', false), ('tard', false),
  ('mongoloid', true), ('spaz', false), ('spastic', false), 
  -- Sexual content involving minors, and sexual violence.
  ('child porn', true), ('childporn', true), ('kiddie porn', true),
  ('kiddy porn', true), ('loli', false),
  ('lolicon', true), ('shotacon', true), ('preteen sex', true),
  ('underage sex', true), ('csam', false), ('rape you', false), ('raped you', false),
  ('i will rape', false), ('gonna rape', false), ('rapeable', true),
  -- Telling someone to hurt or kill themselves.
  ('kill yourself', false), ('kill urself', false), ('kill yourselves', false),
  ('kys', false), ('go die', false), ('neck yourself', false), ('hang yourself', false),
  ('slit your wrists', false), ('drink bleach', false), ('an hero', false)
on conflict (term) do nothing;

-- ── 6. Onboarding's availability check says no up front ──────
-- A reserved or objectionable name reads as taken, rather than passing the
-- check and failing on save.
create or replace function public.username_available(name text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select not public.username_reserved(name)
     and public.objectionable_term(name) is null
     and not exists (
       select 1 from public.profiles
        where lower(username) = lower(trim(name))
          and id is distinct from auth.uid()
     );
$$;

revoke all on function public.username_available(text) from public, anon;
grant execute on function public.username_available(text) to authenticated;
