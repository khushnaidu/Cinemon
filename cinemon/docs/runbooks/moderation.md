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
