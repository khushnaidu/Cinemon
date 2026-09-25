# Runbook: working the report queue

Apple expects reported content to be dealt with within 24 hours (Guideline 1.2), and the support page promises "We review every report". Until the daily email digest exists (ADR 0002 C2), check the queue once a day.

Everything below runs in the Supabase **SQL editor** (the editor runs as `postgres`), or from any admin session in the app's database.

## Once: make yourself an admin

```sql
update public.profiles set is_admin = true where username = '<you>';
```

The SQL editor isn't signed in as you, so `is_admin()` is false there and the queue view comes back empty. Read the reports straight from the tables in the editor instead (next section), or use the functions from a signed-in admin session.

## See what's open

```sql
select target_kind, coalesce(post_id, comment_id, activity_id, activity_comment_id, list_id, profile_id) as target_id,
       count(*) as reports, array_agg(distinct reason) as reasons, min(created_at) as first
  from public.content_reports
 where status = 'open'
 group by 1, 2
 order by 3 desc, 5;
```

`target_kind` is one of `post`, `post_comment` (an Explore reply), `activity` (a review), `activity_comment`, `list`, `profile`. Look the row up in its table (`explore_posts`, `explore_comments`, `activities`, `comments`, `lists`, `profiles`) to read it.

## Act on it

The `mod_*` functions check `is_admin()`, which the SQL editor fails. In the editor, do the same thing by hand; each step matches what the function would log.

**Remove it** (not for profiles). Keep a copy first, since its reports go with it:

```sql
insert into public.moderation_actions (action, target_kind, target_id, target_user_id, reason, snapshot)
select 'remove_content', 'activity', a.id, a.user_id, '<why>', to_jsonb(a)
  from public.activities a where a.id = '<id>';
delete from public.activities where id = '<id>';
```

Swap the table and kind for other content.

**Dismiss the reports** (nothing wrong with it):

```sql
update public.content_reports set status = 'dismissed', reviewed_at = now()
 where '<id>' in (post_id, comment_id, activity_id, activity_comment_id, list_id, profile_id)
   and status = 'open';
```

**Suspend the account** (repeated or serious abuse; a suspended account can't post, comment or log):

```sql
update public.profiles set suspended_until = now() + interval '7 days' where id = '<user id>';
```

For a profile report about the bio, name or photo, edit the field to empty rather than removing anything:

```sql
update public.profiles set bio = null where id = '<user id>';
```

From a signed-in admin session the same actions are `mod_remove_content(kind, id, reason)`, `mod_dismiss_reports(id, reason)` and `mod_suspend_user(user_id, until, reason)`, and `moderation_queue` shows everything open with a text excerpt.

## Automatic checks (migrations 020 and 022)

Text is checked by the database before it's saved (`objectionable_term`); photos by the `moderate-image` Edge Function before anything shows them. Neither needs you day to day. To add a banned term, or allow an innocent word that contains one:

```sql
insert into public.moderation_terms (term, anywhere) values ('some slur', false);
insert into public.moderation_allowed_words (word) values ('scunthorpe');
```

`anywhere = true` also matches inside words and spelled-out letters; use it only for long terms that aren't part of ordinary words.

Refused photos, newest first:

```sql
select checked_at, bucket, path, owner_id, verdict, categories
  from public.media_checks where verdict <> 'ok' order by checked_at desc;
```

## A photo flagged as involving a minor (`verdict = 'minors'`)

US law (18 U.S.C. 2258A) requires reporting apparent child sexual abuse material to NCMEC and preserving it for a year. The function has already moved the file to the private `quarantine` bucket, removed it from the app, and suspended the account. Check daily:

```sql
select * from public.media_checks where verdict = 'minors' and reported_at is null;
```

For each one:

1. Don't download, copy or forward the file. Look at it only as far as needed to judge whether it's apparent CSAM (Dashboard → Storage → quarantine). If it clearly isn't (a false positive), restore nothing: lift the suspension with `mod_suspend_user(id, null, 'false positive')`, delete the quarantined file, and mark the row reported with `report_id = 'false positive'`.
2. Otherwise, file a CyberTipline report at report.cybertip.org, using the ESP account (register once at esp.ncmec.org/registration). Include the account's username, email, the upload time and the file.
3. Record it: `update public.media_checks set reported_at = now(), report_id = '<NCMEC report number>' where bucket = '…' and path = '…';`
4. Leave the account suspended and the file in quarantine for one year from the report, then delete both.
