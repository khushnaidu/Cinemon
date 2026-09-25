-- Critiques are long-form: up to 12,000 characters (about 2,000 words).
-- Everything else stays at 4,000, takes at 280 and list captions at 500.
-- Run after 029. Safe to re-run.

alter table public.explore_posts drop constraint if exists explore_posts_body_check;
alter table public.explore_posts add constraint explore_posts_body_check
  check (char_length(body) <= case when kind = 'critique' then 12000 else 4000 end
         and (kind = 'list' or char_length(body) >= 1));
