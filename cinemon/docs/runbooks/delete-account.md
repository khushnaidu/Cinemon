# Runbook: delete an account on request

Use this when someone emails support@35mm.contact asking for deletion and can't do it in the app (Settings → Delete account). Deletion in the app does exactly the same thing.

1. **Check it's them.** The request must come from the address the account signed up with. Look it up in Supabase → Authentication → Users, or run this in the SQL editor:
   ```sql
   select u.id, u.email, p.username
     from auth.users u join public.profiles p on p.id = u.id
    where u.email = '<address>';
   ```
2. **Delete their files.** In Supabase → Storage, delete the `<uid>` folder in both the `avatars` and `review-media` buckets. Storage has no cascade, and Supabase doesn't allow deleting storage rows from SQL.
3. **Delete the account.** Either delete the user in Authentication → Users, or run this in the SQL editor:
   ```sql
   delete from auth.users where id = '<uid>';
   ```
   Everything they own cascades from there, and other people's counts are fixed by triggers.
4. **Reply** to confirm the account is deleted, within 30 days of the request, as promised on /privacy.
