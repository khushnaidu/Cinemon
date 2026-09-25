# ADR 0004 — Accounts: reporting everything, real auth, public and private profiles

- **Status:** Accepted 2026-09-24. Phases 1, 2 and 4 built 2026-09-24; Phase 3 (Apple and Google) waits on the Apple account.
- **Date:** 2026-09-24
- **Scope:**
  - Making every piece of user content reportable.
  - Rebuilding sign-up and sign-in: email verification, password rules, password reset, Sign in with Apple, Google.
  - Moving from mutual friendships to one-way follows, with public accounts by default and a private switch.
  - Restyling the auth screens and the Follow button.
- **Related:**
  - ADR 0002: C1 deletion, C2 moderation, C3 report-hide, C4 block. This ADR widens C2 and C3 from Explore posts to all content.
  - ADR 0003 Phase 4: the `/p/` and `/u/` links, which now have to respect private accounts.
- **Why now:** App Store submission is paused until this lands (owner, 2026-09-24).

---

## 1. Context

A survey of the code on 2026-09-24 found the following.

**Reporting**
- Only **Explore posts** can be reported (`explore_thread.dart`).
- These have no Report action: reviews and their photos and voice notes, comments on reviews, Explore replies, playlists, profiles.
- `content_reports` has an unused `comment_id` column and nothing else. The `moderation_queue` view and the `mod_*` functions only understand Explore posts.
- Guideline 1.2 expects every kind of user-generated content to be reportable.

**Following**
- A follow is a **mutual friendship**. Every follow is a request, and an accepted row counts both ways (`sync_follow_counts`).
- A declined row is never deleted, so "Follow" after a decline throws "Friend request already exists". That's a live bug.
- Visibility ignores following almost everywhere:
  - `activities`, `comments`, likes, reactions, `explore_posts` and `explore_comments` are all `select using (true)`.
  - Only `home_feed` (the circle CTE) and `lists` with visibility `friends` look at friendships.
  - `is_following()` exists but nothing calls it.

**Auth**
- Email and password only, with a 6-character minimum.
- Signup always goes to `/profile-setup`, even when there's no session yet.
- "Forgot password" is a toast saying "coming soon". `sendPasswordResetEmail` exists but nothing calls it.
- No verification UI, no Apple, no Google.
- `handle_new_user` reads only `username` from the sign-up metadata, and otherwise invents `user_xxxxxxxxxx`.

**UI**
- The login and sign-up fields are white-outlined pills, and the buttons are solid white `ElevatedButton`s.
- On someone else's profile, Follow is a 200-wide white `ElevatedButton`.
- All of this breaks the house rule: glass first, and selection is a brighter `GlassLens`, never solid white.

## 2. Decisions

### D1 — One report sheet, every kind of content

**What can be reported:**
- Reviews and episode logs, including their photos and voice note (one report covers the whole review).
- Comments on reviews.
- Explore posts.
- Explore replies.
- Playlists.
- Profiles: username, name, bio and avatar.

**Not reportable:** likes, reactions and votes. They carry no free text, and blocking covers abuse through them.

**Schema** (migration `014_reports_everywhere`):
- `content_reports` gains `activity_id`, `activity_comment_id`, `list_id` and `profile_id`, each a nullable foreign key with `on delete cascade`.
- The target check becomes "exactly one target is set".
- `unique (reporter_id, post_id)` is replaced by one partial unique index per target column. Reporting twice is still a no-op.
- A generated `target_kind` column (`post`, `post_comment`, `activity`, `activity_comment`, `list`, `profile`) makes the queue simple.

**Report-hide (ADR 0002 C3), extended:** whatever you report disappears for you.
- **Explore posts:** already hidden (`explore_feed`).
- **Reviews:** `home_feed` and `feed_activities` hide ones you've reported.
- **Comments and replies:** hidden in the comment queries.
- **Playlists:** hidden from lists you browse.
- **Profiles** are not hidden. You're offered Block alongside the report instead.

**Moderation:**
- `moderation_queue` becomes a union across all kinds, each row showing a text snapshot of the reported item.
- `mod_remove_post` is generalised to `mod_remove_content(kind, id, reason)`. It deletes the item and logs a snapshot to `moderation_actions`, as before.
- Profiles have no "remove". They're actioned with `mod_suspend_user`, or by clearing the bio or avatar by hand.

**App:**
- `showReportSheet(context, ReportTarget)` holds the shared reasons, taken from `explore_thread.dart`, with "Under 13" added for profiles.
- It's added to the ••• menu on:
  - Review cards (home feed, film page, profile activity).
  - Comment rows (long-press, as delete works today).
  - Explore replies.
  - The playlist screen.
  - Someone else's profile: Report @x sits next to Block @x.

### D2 — One-way follows, like Instagram

Owner's decision, 2026-09-24.

**The table**
- A new table: `follows (follower_id, followee_id, status 'pending'|'accepted', created_at, accepted_at)`.
  - Primary key `(follower_id, followee_id)`.
  - No self-follows.
  - Insert is blocked when either side has blocked the other.

**Status is decided by the server, not the client**
- A `before insert` trigger sets `status`: `accepted` if the followee is public, `pending` if private.
- Only the followee can move a row from `pending` to `accepted`. The column is guarded, the same way the moderation columns are.
- **Decline** deletes the row. So does **remove follower**, done by the followee. **Unfollow** or **cancel request** is a delete by the follower. No row ever gets stuck, which fixes the re-follow bug.
- When an account goes **private → public**, every pending request to it is accepted.

**Counts and notifications**
- `follower_count` and `following_count` now count one direction only.
- Notifications:
  - A new `follow` type ("started following you") for public accounts.
  - `followRequest` for private accounts.
  - `followAccepted` when a request is approved.
  - The enum value goes in its own migration (`016_notification_types`), run before `017`, as with `011a`.

**Moving existing data** (migration `017_follows`)
- Every accepted friendship becomes **two accepted follows**, so nobody loses anyone.
- Every pending friendship becomes an accepted follow from the sender, and its notification becomes "started following you": everyone starts public, and public accounts don't take requests (amended while building).
- Declined friendships are dropped.
- `friendships` stays in place, unused, until every TestFlight tester is on the new build. A later migration drops it.

**Names in the app:** "Friends" becomes **Followers / Following**. The friends-list screen gets two tabs. The Home feed's circle becomes "you plus accepted follows". Playlist visibility `friends` becomes **Followers** and keeps the same stored value.

### D3 — Public by default, a private switch, header-only when private

Owner's decision, 2026-09-24.

**The switch:** `profiles.is_private boolean not null default false`, found under Settings → **Private account**.

**The check:** one helper, `can_see(owner uuid)` (security definer, stable), is true when any of these holds:
- you are the owner, or
- neither of you has blocked the other, and the owner is public, or
- neither of you has blocked the other, and you have an accepted follow to them.

Every SELECT policy on user content uses it:

| Table | Visible when |
|---|---|
| `activities`, `explore_posts`, `user_badges`, `person_follows` | `can_see(user_id)` |
| `comments`, `activity_likes`, `activity_reactions` | You can see the parent review |
| `explore_comments` | You can see the parent post. Replies from a private account on a public post stay visible, as on Instagram, where a comment belongs to the post it's on. |
| `lists` / `list_items` | `can_view_list` also requires `can_see(owner)` for public lists. "Followers" lists need an accepted follow. |
| `follows` | Your own rows, plus rows of anyone you `can_see`. A private account's follower list is hidden from non-followers. |
| `profiles` | Unchanged. The header (avatar, name, username, bio, counts) is always visible unless blocked, and is the basis for the locked view. |

Views inherit these rules through `security_invoker`. So Explore, Home, search and share links all obey them with no extra code. A `/p/<id>` link to a private post shows "This post isn't available" to non-followers.

**The locked view:** a private profile shows the header, a **Follow / Requested** button, and a glass "This account is private" panel in place of the tabs.

**Known limit:** the `review-media` and `avatars` buckets stay public-by-URL. The paths are random UUIDs and are only discoverable through rows that RLS now hides. Signed URLs would cost a lot of latency and caching for little gain. Revisit this if a private-media feature arrives.

**The website:** 35mm.contact's `/p/` and `/u/` fallback pages must not render the content of private accounts. The `/open` page only shows a generic card today, so check this rather than assume it.

### D4 — Codes in emails, not deep links

Supabase's email carries a **6-digit code and no link** (amended while building Phase 2).
- **The app asks for the code.** A code works when the email is opened on a laptop and needs no working deep link.
- **No link, deliberately:** the link and the code share one one-time token, and mail apps prefetch links, which would use it up before the code is typed.

**The flows:**
- **Sign up:** email and password → the "Check your email" screen: enter the code, Resend after 60 s, Open Mail. `verifyOTP(type: signup)` returns a session → onboarding.
- **Forgot password:** email → code → new password (`verifyOTP(type: recovery)`, then `updateUser(password)`) → signed in.
- **Change email** later uses the same code screen.

**Supabase settings** (owner, in the dashboard):
- Turn **Confirm email** on.
- Turn **Secure email change** on.
- Paste the templates in `supabase/templates/` for Confirm signup and Reset password. They show `{{ .Token }}` and no link.
- OTP expiry: 1 hour.

**Custom SMTP is required for launch.** The built-in sender is limited to a handful of emails an hour. Use Resend on `35mm.contact` (SPF and DKIM on the Vercel DNS), sending from `hello@35mm.contact`.

### D5 — Password rules

- At least **8 characters**, with at least one letter and one number. Enforced in two places:
  - In Supabase: Auth → Providers → Email → minimum length 8, "Lowercase, uppercase letters and digits" off, "Letters and digits" on.
  - In the app: a live checklist under the field that ticks each rule as it's met.
- The server is the authority. The app maps `weak_password` errors to plain text.
- Leaked-password protection (HaveIBeenPwned) needs the Supabase Pro plan. Turn it on if the org upgrades; see Risks.

### D6 — Sign in with Apple and Google, natively

- **Apple:** the `sign_in_with_apple` package asks for `email` and `fullName`, with a SHA-256 nonce. The ID token goes to `signInWithIdToken(provider: apple, nonce)`.
  - Apple sends the name only on the **first** sign-in, so it's saved to `display_name` straight away.
  - Needs the "Sign in with Apple" capability in `Runner.entitlements`, and the Apple provider in Supabase with client ID `com.cinemon.app`.
- **Google:** the `google_sign_in` package, with the iOS client ID plus the Web client ID as `serverClientId`. The ID token goes to `signInWithIdToken(provider: google)`.
  - Needs `GIDClientID` and the reversed-client-ID URL scheme in `Info.plist`.
  - In Supabase, the Google provider lists both client IDs as authorized and has **Skip nonce check** on (the iOS SDK doesn't pass one through).
- **Linking:** Supabase links identities that share a verified email. So a password account and a Google sign-in with the same address become one user. Apple's private-relay addresses won't link, which is expected.
- **Guideline 4.8** requires Apple wherever Google is offered, and we offer both.
- **Guideline 5.1.1(v): Apple token revocation.** Deleting an account created with Sign in with Apple must revoke its Apple token.
  - At sign-in the app sends Apple's `authorizationCode` to an Edge Function, `apple-token`. The function exchanges it for a refresh token using our `.p8` key and stores it in `private.apple_tokens`, which is not exposed to the API.
  - `delete_my_account` then calls the function's revoke path before the auth user is deleted.
  - This is the first Edge Function. It's deployed from the dashboard editor, since there's no CLI.
- **Button styling:** glass pills, "Continue with Apple" with the white Apple logo and "Continue with Google" with the four-colour G. Both follow Apple's HIG rules for custom Sign in with Apple buttons (logo, title, minimum size, radius) and Google's branding rules. No white fills.

### D7 — Onboarding picks the username, for everyone

- Sign-up no longer asks for a username. Every new account, whether email, Apple or Google, goes through **onboarding**:
  1. **Username**, with a live availability check.
  2. **Name**, prefilled from Apple or Google.
  3. **Photo**, with Google's avatar offered.
  4. **Private account** switch (default off).
  5. **Done.**
- `profiles.onboarded_at timestamptz`. Existing accounts are backfilled to `created_at`.
- The router redirects any signed-in user with `onboarded_at is null` to `/onboarding`. This replaces the optional `/profile-setup`, which nothing redirected to anyway.
- `handle_new_user` keeps inventing a placeholder username so the unique `not null` constraint holds until onboarding replaces it.

### D8 — Glass inputs and buttons; no solid white controls

- **New primitive, `GlassTextField`:**
  - A single-line glass well: 52 high, with a leading SF icon.
  - An optional trailing action, such as show or hide password.
  - An inline error line under the field, used instead of a toast for field errors.
  - A focus ring that brightens the glass rim rather than drawing a white outline.
- **Auth screens** (login, sign-up, code, new password, onboarding):
  - The logo, then glass fields.
  - `GlassPillButton(prominent: true)` for the main action, which is the lens treatment.
  - An "or" divider, then the Apple and Google pills.
  - The fade and zoom intro on login is kept.
- **Follow button** (`profile_header.dart`):

  | State | Button |
  |---|---|
  | Follow / Follow back | `GlassPillButton(prominent)` |
  | Following / Requested | Plain `GlassPillButton` |

  - An incoming request shows an **Accept / Delete** glass row above the stats, rather than replacing the button.
  - A small "Follows you" `GlassTag` sits next to the username.
- **Follow requests** get their own row at the top of Notifications, "Follow requests (n)", opening a glass list with Confirm / Delete. This matches Instagram.

## 3. Build order

Each phase is its own branch and ends with a TestFlight build, so testers see progress.

| Phase | Ships | Needs from the owner |
|---|---|---|
| **1. Report everything** | D1: migration `014`, `showReportSheet`, menus on all content, moderation queue across kinds. Also locks the iPhone app to portrait. | Paste `014` into the SQL editor |
| **2. Auth core and restyle** | D4, D5, D7, D8 (`GlassTextField`, login, sign-up, code screen, forgot password, onboarding). Migration `015_onboarding`. | Dashboard settings in D4 and D5. Resend and SMTP (can come later; codes work with the built-in sender at low volume) |
| **3. Apple and Google** | D6, including the `apple-token` Edge Function and revoke-on-delete | Apple: enable the capability on the App ID, create a Services ID and a `.p8` key. Google: Cloud project with iOS and Web OAuth clients. Supabase: enable both providers. Step-by-step instructions come with the phase. |
| **4. Follows and private accounts** | D2, D3, and the D8 Follow button, requests, locked profile, Followers/Following tabs. Migrations `016_notification_types`, `017_follows`, `018_explore_notifications`. | Paste the migrations, **at the same time as the build goes out** (older builds read `friendships`) |
| **Then** | Update the website's privacy page (Apple and Google sign-in, private accounts, the reporting scope) and check the `/p/` and `/u/` fallbacks. Resume the App Store checklist. | — |

**Progress:**

- **Phase 1:** built 2026-09-24.
  - `014_reports_everywhere.sql` tested on the scratch cluster:
    - All six kinds can be reported, and each hides for the reporter.
    - Duplicate, self and impersonated reports are rejected.
    - The admin-only queue works, as do remove, dismiss and suspend.
    - Rerunning the file is clean.
  - The report-hide lives in the tables' read policies (`i_reported()`), not in individual views.
  - App entry points:
    - Explore post ••• (now the shared sheet).
    - Review card back ••• (Home).
    - Friends' reviews on the film page.
    - Long-press on a profile's review grid.
    - Every comment and reply (••• or long-press: Report, Block, and Delete where allowed).
    - Playlist **More**.
    - Profile ••• → Report @x, which then offers Block.
  - The iPhone app is portrait-only.
  - Runbook: `docs/runbooks/moderation.md`.
- **Phase 2:** built 2026-09-24.
  - `015_onboarding.sql`:
    - `profiles.onboarded_at`, backfilled for everyone existing, only on the first run.
    - `handle_new_user` fills the name and photo from the provider.
    - `guard_username()` checks the format only when the username changes.
    - `username_available()`.
    - Tested on the scratch cluster, including a rerun.
  - The app:
    - `GlassTextField` and `AuthScaffold`.
    - Log in, sign up (email and password with a live checklist), `/verify` (the 6-digit code, with Resend after 60 s and Open Mail), `/forgot`, `/new-password` and `/onboarding` (username with a live availability check, then photo, name and bio).
  - The router is now a single instance using `refreshListenable`, so login no longer replays the splash. `authRedirectHold` lets the login zoom finish.
  - The rules are shared with Edit Profile (`lib/core/utils/auth_rules.dart`, unit-tested).
  - The email templates are in `supabase/templates/`.
  - The website gains `/terms` (zero tolerance for objectionable content, as Guideline 1.2 expects), linked from sign-up.
- **Phase 4:** built 2026-09-24.
  - `016_notification_types` and `017_follows`, tested on the scratch cluster:
    - Seeded with accepted, pending and declined friendships, then 20 behaviour checks across six users.
    - Also covered: account deletion, and a rerun of the file.
    - One amendment from testing: a follow row is visible only when you can see both people, so a private account's followers can't be listed through its public followers.
  - The app:
    - `FollowRepository` and `follow_provider.dart` replace the friendship code.
    - The Follow button: Follow, Follow back, Requested, Following.
    - A "Follows you" tag, and a "wants to follow you" row with Confirm and Delete.
    - A locked profile when private.
    - Settings → Private account, and a private switch in onboarding.
    - People (`/friends`) and anyone's `/follows/<id>`: Followers and Following, with Remove and unfollow on your own.
    - Follow requests at the top of Notifications and People.
    - The `follow` notification type.
    - Playlist visibility "Friends" is now "Followers".
  - Website privacy and support pages updated.
  - Follow-ups from the owner, same day:
    - Mutual follows show **Friends** on the button, and the separate "Follows you" tag is gone.
    - `018_explore_notifications` notifies on votes on your posts (one per voter; a changed vote updates it, a withdrawn one removes it), on replies to your posts and replies, and on saves of your playlists.
    - Tapping a notification opens its subject: the review, the comment sheet, the Explore thread or the playlist. The avatar opens the person.
    - Activity has glass filter chips: All, Likes, Comments, Votes, Saves, Follows. Shares can't be counted, since sharing leaves no record.
    - Saved playlists show under **Saved** on your own Lists tab. They had no home before.
- **Pre-submission audit:** 2026-09-24.
  - `019_suspension_everywhere`: a suspended account can't create or edit playlists, add films to them, or change its name, username, bio or photo. It can still remove things, go private and delete the account. Tested with 8 checks and a rerun.
  - Film pages: friends' reviews are filtered by media type and by who you follow on the server. They used to take everyone's latest 20 and filter on the phone, and could show a TV show's reviews on a film with the same id.
  - Settings → About: Terms, Privacy, Help and contact, Licences (bundled font licences are registered), and the TMDB credit.
  - `schema.sql` is marked baseline-only.
  - **When `friendships` is dropped**, redefine `on_user_block` first: it still deletes from that table (017).

Every migration is tested first on the local Postgres 16 scratch cluster, with the stub `auth` and `storage` schemas, acting as several users under `set role authenticated`.

## 4. Risks

- **The follow migration is the riskiest change.** It rewrites the social graph, and older builds break when `friendships` stops being written to. Mitigations:
  - It's rehearsed locally with the live row counts.
  - Pasting the migration is timed with the build release.
  - `friendships` is kept, not dropped, so the change can be rolled back.
- **The Supabase org is on the Free plan.** That means a limited email rate, no leaked-password check, and the project pauses after a week of inactivity. Pro is recommended before launch.
- **RLS cost.** `can_see()` runs per row. It's one indexed lookup on `follows (follower_id, followee_id)` plus the profile's `is_private`, which is cheap at our size. Recheck the Explore and Home query plans after Phase 4.
- **Apple token revocation** is rarely checked by App Review but is in the guidelines. It is built rather than deferred.
