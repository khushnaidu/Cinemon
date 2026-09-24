# ADR 0002 — Commitments made on 35mm.contact that the app must honour

- **Status:** Accepted: these are owed, not optional
- **Date:** 2026-09-23
- **Scope:** Every claim on `35mm.contact/privacy` and `35mm.contact/support` (repo `khushnaidu/35mm`) that the app or backend doesn't fully back up today
- **Related:** ADR 0001 (feature wave 2). App Store Review Guidelines 1.2 (UGC) and 5.1.1(v) (account deletion).

---

## 1. Context

The privacy policy and support page went live on 2026-09-23. They describe how 35mm *should* behave. A line-by-line audit against the code found claims that are true, claims that are true only in the UI, and claims that describe a manual process that doesn't exist yet.

**Rule going forward:** the website never gets ahead of the app. When a claim changes, this ADR (or its successor) is updated in the same change as the page. When an item below ships, tick it and note the date.

### Audit: claims already true (no action)

| Claim | Where it holds |
|---|---|
| No analytics, ads or tracking SDKs | `pubspec.yaml`. Note that `google_fonts` is listed but unused, so remove it anyway. |
| Photos, camera and microphone only when you use the feature | `Info.plist` usage strings. Permissions are requested on use. |
| Voice recording starts on tap and stops on tap or after 10 s | `review_media_composer.dart` (`kMaxVoiceNote` cap). The page was corrected on 2026-09-23, because it previously said "hold". |
| Deleting a review removes its photos and voice note | `FeedNotifier.deleteActivity` → `deleteReviewMedia`. Best-effort, see C7. |
| Edit/delete Explore posts via •••, "edited" label | Explore (migration 004, `stamp_explore_edit`). |
| No comments on hot takes, reviews and critiques | `ExploreKind.allowsComments` + the RLS in migration 005. |
| Log a single episode from a show's page | `EpisodesSection` (migration 003). |
| Each account can change only its own content | RLS on every table. |

---

## 2. Commitments not yet honoured

Priority key:

- **P0:** must ship before App Store submission (App Review will reject, or the claim is materially false).
- **P1:** before public launch.
- **P2:** can follow.

### C1 — Account deletion `P0`

- **Page says:**
  - *Privacy:* "Deleting your account removes your profile, logs, posts, comments, votes, follows, photos and voice notes", and "We'll confirm within 30 days."
  - *Support:* email-based deletion.
- **Today:** there is no deletion path at all, in the app or on the backend.
- **Decision:**
  - **In-app:** Settings → **Delete account**, behind a glass confirm and then a typed confirmation of your username. Guideline 5.1.1(v) requires that users can *start* deletion in the app, so email-only will be rejected.
  - **Backend (revised while building, 2026-09-23):** no Edge Function. The Supabase CLI isn't set up, and none is needed:
    1. The app empties `avatars/{uid}/` and `review-media/{uid}/` through the Storage API first (`UserRepository.deleteAccount`). Storage has no cascade, and Supabase blocks deleting storage rows from SQL. The storage RLS already lets a user delete their own folder. If this step fails, nothing else has been touched and the user can retry.
    2. The app calls `delete_my_account()` (migration `006`), a `security definer` function that deletes `auth.users` where `id = auth.uid()`. `profiles` cascades from `auth.users`, and every other table cascades from `profiles`.
    3. Counters on *other* users are corrected by the existing triggers as the cascade runs. The local Postgres behaviour test confirms this for follows and blocks.
  - **Email route kept** for people who can't sign in. For those requests, run the storage cleanup and `delete from auth.users where id = '<uid>'` from the dashboard (see `docs/runbooks/delete-account.md`).

### C2 — Reports are reviewed `P0`

- **Page says:**
  - *Support:* "We review every report."
  - *Privacy:* "review reported content and act on accounts that break the rules."
- **Today:**
  - Reports land in `content_reports`, and nobody looks at them.
  - There's no way to remove someone else's post or suspend an account except by hand in SQL.
- **Decision:**
  - A **`moderation_queue` view** (reports grouped by post, with count, reasons, post body and author) that is readable only by admins.
  - An **`is_admin` flag on `profiles`**. Only the service role can write it, which a column-privilege revoke enforces.
  - **v1 review:** the Supabase dashboard reading the view, with two `security definer` RPCs that only admins can execute:
    - `mod_remove_post(post_id, reason)`
    - `mod_suspend_user(user_id, until)`
  - **v2 review:** a hidden in-app Moderation screen for admins.
  - **Suspension:** `profiles.suspended_until`. RLS insert policies on posts and comments check it.
  - **Report status columns:** `status` (`open` / `actioned` / `dismissed`), `reviewed_at`, `reviewed_by`.
  - **Alerting:** a daily email digest of open reports, from a cron Edge Function. Guideline 1.2 expects objectionable content to be acted on "within 24 hours". **Not built yet**: it needs the Supabase CLI and an email sender. Until then, check `moderation_queue` in the dashboard every day.
  - **Built (migration `007`):** `is_admin` and `suspended_until` guarded by a trigger; `is_admin()` and `is_suspended()`; suspended accounts can't insert posts, comments or logs; report `status` / `reviewed_at` / `reviewed_by`; a `moderation_actions` log that keeps a snapshot of removed posts; the admin-only `moderation_queue` view; and `mod_remove_post`, `mod_dismiss_reports` and `mod_suspend_user`.

### C3 — Reported posts stay hidden `P0`

- **Page says:** *Support:* "Reported posts are hidden from you right away."
- **Today:** the post is removed from local feed state only, so it **comes back on refresh or a filter change**.
- **Decision:** the `explore_feed` view adds `and not exists (select 1 from content_reports r where r.post_id = e.id and r.reporter_id = auth.uid())`. The local removal stays for immediacy.

### C4 — Block users `P0`

- **Page:** doesn't say it yet, but Guideline 1.2 requires "the ability to block abusive users" for any UGC app, and Explore makes 35mm one.
- **Decision:**
  - A `user_blocks(blocker_id, blocked_id)` table.
  - **As built (migration `007`):** enforcement sits on the `profiles` select policy (`not is_blocked_pair(auth.uid(), id)`). Every feed view and comment query inner-joins the author's profile, so one policy hides content everywhere, in both directions. Notifications (left join) and friendship inserts have their own checks, and a trigger ends any follow when a block is created. `my_blocked_accounts()` feeds the Blocked accounts list, because blocked profiles are hidden from the table.
  - Entry points: the profile ••• menu and the post ••• menu ("Block @user").
  - A Settings → Blocked accounts list to unblock.
  - After it ships, add a "How do I block someone?" FAQ.

### C5 — Email is private `P0`

- **Page says:** *Privacy:* "It isn't displayed in the app."
- **Today:** true in the UI, but `profiles` is `select … using (true)` **including `email`**, so any signed-in client can read every user's email through the API. The claim is literally true, but it isn't what users would reasonably expect it to mean.
- **Decision (revised while building, 2026-09-23):** **drop** `profiles.email` rather than revoke read access to the column.
  - The copy was never needed. `auth.users` holds the address, and the client reads its own email from the session.
  - A column revoke only takes effect after revoking table-level `select` and re-granting every other column. Every new `profiles` column would then need its own grant, and every `select()` (which means `*`) in `user_repository.dart` would fail. That includes the realtime stream the profile screen uses.
  - Migration `006` rewrites `handle_new_user()` without the email and then drops the column. `schema.sql` and `UserModel` drop it too.
  - **Rollout:** apply `006` and install the new build together. Older builds still require `email` when they parse a profile.

### C6 — Support inbox exists `P0`

- **Page says:** every page links to `support@35mm.contact`, and *Support* says "We usually reply within two days."
- **Today:** the domain has no MX records, so mail bounces.
- **Decision:** set up ImprovMX (free), forwarding to the owner's inbox, with its MX records added in Vercel DNS. Send a test email and confirm it arrives.

### C7 — Deleted media really goes away `P1`

- **Page says:** *Privacy:* "If you delete a post, comment, photo or voice note, it's removed from our database and storage."
- **Today:** Storage cleanup is best-effort and happens after the row delete. A failure orphans the files forever. Avatar replacement also needs checking to confirm it removes the old file.
- **Decision:** a weekly cron Edge Function `storage-sweeper` lists `review-media/` and `avatars/` and deletes objects whose owning row no longer exists (and which are older than 24 h, so it can't race an upload in progress).

### C8 — Vote privacy `P1`

- **Page says:** *Privacy:* "Who voted which way is not shown."
- **Today:** true in the UI, but `explore_post_votes` is readable by all authenticated users.
- **Decision:** change the select policy to own rows only (`auth.uid() = user_id`). Counts come from trigger-kept columns, and `my_vote` in `explore_feed` already filters on `auth.uid()`, so nothing in the app changes.

### C9 — Under-13s `P1`

- **Page says:** *Privacy:* "35mm isn't meant for children under 13…"
- **Today:** there's no age signal at sign-up.
- **Decision:**
  - Add an age confirmation at sign-up ("I'm 13 or older", required) and store `profiles.age_confirmed_at`.
  - Set the App Store age rating to reflect user-generated content, answering the UGC questions honestly (expected result: 12+ or higher).
  - A report reason "Under 13" feeds the C2 queue.

### C10 — Access and export on request `P1`

- **Page says:** *Privacy:* you may have the right to "access, correct, export or delete".
- **Today:** only editing in the app exists.
- **Decision:** a `security definer` RPC `export_my_data()` that returns one JSON document (profile, activities, Explore posts, comments, votes, follows and reports made), plus media URLs. v1 is run by us on an email request (runbook). v2 adds Settings → **Download my data**, which shares the JSON file.

### C11 — Policy-change notice `P2`

- **Page says:** *Privacy:* "If the change is significant, we'll also tell you in the app."
- **Decision:** add `app_config.policy_version` (a single-row table) and `profiles.policy_seen_version`. When they differ, show a one-time glass panel ("We've updated our Privacy Policy") linking to the page, and update `policy_seen_version` when it's dismissed.

### C12 — Breach notification `P2` (operational)

- **Page says:** *Privacy:* "…will notify you if a breach affects you."
- **Decision:** there's no code beyond what already exists, because sign-in emails are in `auth.users`. Write `docs/runbooks/incident.md`: rotate keys (Supabase service role, TMDB), assess scope, and email affected users through Supabase Auth's SMTP or a one-off send.

---

## 3. Build order

| Order | Items | Why |
|---|---|---|
| 1 | **C6** (inbox), **C5** (email column), **C3** (persisted report hide), **C8** (vote privacy) | These are config plus one small migration (`006_privacy_hardening.sql`). They take under an hour together, and close the gap between page and reality immediately. |
| 2 | **C1** (account deletion) | App Review blocker. It brings in the first Edge Function, which C2, C7 and ADR 0001 Phase 6/7 all reuse. |
| 3 | **C4** (block) + **C2** (moderation) | These are the Guideline 1.2 set, and they share RLS helpers (`is_blocked(a, b)`, `is_admin()`). |
| 4 | **C9**, **C7**, **C10** | Before public launch. |
| 5 | **C11**, **C12** | As they come up. |

**Effect on ADR 0001:** items 1–3 here go **ahead of** ADR 0001's watchlist phase. ADR 0001's Phase 1 (film detail upgrades, TMDB-only, no migration) can run in parallel with item 1, because they don't touch the same code. Migration numbering shifts accordingly: privacy hardening becomes `006`, and lists move to `007`.

---

## 4. Consequences

- **Submission-readiness list:** C1–C6 are now the gate. Nothing ships to App Review until they're ticked.
- **Operational commitments:** "reply within two days" and "act within 24 hours" are promises that someone reads the inbox and the moderation digest. That's a people cost, not a code one.
- **Website changes:** any new feature that touches personal data (lists visibility, person follows, the trailer feed) needs a line on `/privacy` in the same release.

## 5. Checklist

- [x] C1 In-app account deletion (`delete_my_account()` in `006`, Settings → Delete account). Built 2026-09-23, with runbook `docs/runbooks/delete-account.md`.
- [ ] C2 Moderation queue, admin RPCs and suspension built in `007` (2026-09-23). Daily digest outstanding.
- [x] C3 `explore_feed` hides posts you reported (`006`, 2026-09-23)
- [x] C4 Block users: table, RLS, post and profile menus, Blocked accounts list (`007`, 2026-09-23). FAQ is written; push it with the release.
- [x] C5 `profiles.email` dropped (`006`, 2026-09-23)
- [ ] C6 `support@35mm.contact` forwarding (ImprovMX + MX records) and a test email
- [ ] C7 `storage-sweeper` cron, and verify avatar replacement cleanup
- [x] C8 `explore_post_votes` select limited to own rows (`006`, 2026-09-23)
- [ ] C9 Age confirmation at sign-up, App Store age rating, "Under 13" report reason
- [ ] C10 `export_my_data()` RPC + runbook, and later in-app download
- [ ] C11 Policy-version notice
- [ ] C12 Incident runbook
