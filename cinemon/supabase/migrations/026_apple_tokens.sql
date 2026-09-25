-- Sign in with Apple refresh tokens, kept so deleting an account can revoke
-- its Apple sign-in (App Review 5.1.1(v); supabase/functions/apple-revoke).
-- Private: no policies, so only the service role (the function) can read or
-- write them. Run after 025. Idempotent.

create table if not exists public.apple_tokens (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  updated_at    timestamptz not null default now()
);
alter table public.apple_tokens enable row level security;
revoke all on public.apple_tokens from anon, authenticated;
