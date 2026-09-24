# ADR 0001 — Feature wave 2: trailers, people, lists, profile tabs, where to watch

- **Status:** Proposed
- **Date:** 2026-09-23
- **Scope:** Six features from the "35mm Plans" list, plus the shared infrastructure they need
- **Supersedes:** nothing. Builds on migrations 001–005 and the Explore work.
- **Amended by:** [ADR 0002](0002-website-commitments.md). Its P0 items (privacy hardening, account deletion, block and moderation) go ahead of Phase 3 here, and migration numbers below shift by two: `006` is privacy hardening plus account deletion, `007` is blocking and moderation, and ADR 0001's own migrations start at `008`.

---

## 1. Context

### Where the app is today

| Area | State | Relevant to |
|---|---|---|
| **TMDB** (`movie_repository.dart`, Dio) | Search, details, seasons, trending/popular/now playing/upcoming, genres, and person search/details. There is a `movieCredits` constant but no call uses it. No `videos`, `watch/providers`, `release_dates` or `combined_credits`. No `append_to_response`. | 1, 2, 6 |
| **Film detail** (`film_detail_screen.dart`) | Backdrop app bar, poster/title/meta, tagline, overview, episodes (TV), your activity, and friends' reviews. No cast, trailer or availability. | 1, 2, 6 |
| **People** | `PersonModel` (id, name, profile path, department). `favorite_actor_ids` / `favorite_director_ids` are int arrays on `profiles`. Tapping a person does nothing. There is no person screen. | 2, 5 |
| **Profile** (`profile.dart`, 837 lines) | One long `CustomScrollView` stacking the header, Top 3, actors, directors, badges and a posts grid. | 5 |
| **Badges** | A static `BadgeRegistry`. The client computes badges (`BadgeService`) and writes `profiles.badge_ids`. | 5 |
| **Visibility** | Every table is `select … to authenticated using (true)`. There are no private accounts. Friendships have `pending/accepted`. | 3, 4 |
| **Server-side code** | Only Postgres triggers and functions. **There are no Edge Functions and no cron.** The TMDB key lives only in the client (`dart_defines.json`). | 2, 1 |
| **Deep links** | None. No associated domains, no `app_links`, no share sheet. | 3 |
| **Tab bar** | 4 tabs: Home, Post (`/search`), Explore, Profile, plus native glass chrome gated on `shellChromeVisible`. | 1 |
| **Conventions** | Film metadata is **snapshotted** onto rows (`film_title`, `film_poster_path`, …) so feeds render without TMDB calls. Counters are trigger-kept. RLS does the enforcing, and the client mirrors it. | 3, 4 |

### What we're deciding

1. The order to ship the six features in.
2. The data model and infrastructure for each.
3. The few cross-cutting choices that are expensive to reverse: the list schema, the trailer playback method, and whether to add server-side jobs.

---

## 2. Decision summary

| # | Decision | Why |
|---|---|---|
| D1 | **One enriched TMDB detail call** (`append_to_response=videos,credits,watch/providers,release_dates` for movies, and `aggregate_credits,…` for TV) feeds trailers, cast, person links and where-to-watch. | Film detail gets four features from one request. It keeps us far from TMDB rate limits, and nothing else loads twice. |
| D2 | **Watchlist and playlists share one schema** (`lists` + `list_items`). The watchlist is a system list that each user has exactly one of. | They have the same item shape, the same "Add to…" sheet, the same poster covers and the same profile surface. The watchlist is just the list you can tick off, like Spotify's "Liked Songs". |
| D3 | **Film metadata is snapshotted on `list_items`**, like `activities`. | Lists and 2×2 covers render with zero TMDB calls, and profile tabs stay fast. |
| D4 | **The playlist cover is computed, not generated**: the client draws a 2×2 grid from the first 4 items by position. No image is stored. | The cover is always correct after reordering or removing items, costs no storage, and needs no worker. A server-rendered image is deferred until link previews need one (§4.3). |
| D5 | **Trailers play through YouTube's official IFrame player** (`youtube_player_iframe`), inline and muted in the feed, with one live player at a time. | TMDB videos are YouTube keys. Downloading or re-encoding them breaks YouTube's ToS and App Review guideline 5.2.3. |
| D6 | **Where to watch uses TMDB `watch/providers`** (JustWatch data), with the region taken from the device locale, and shows **JustWatch attribution**. "In theaters" is inferred from `release_dates`. | This is the only licensed and free source. Attribution is a TMDB terms requirement. |
| D7 | **Person pages are TMDB reads. "Follow" is our own table.** New-work alerts come from a **daily Edge Function on `pg_cron`**, which is the app's first server-side job. | "Keep up with what they're working on" needs someone to check for them. A server job is the only honest way to notify. |
| D8 | **Profile becomes a tabbed page**: Posts · Lists · Favorites · Badges. It is one scroll view with a pinned glass segmented header. | This matches the Instagram mental model the brief asks for and splits the 837-line file along natural seams. |
| D9 | **Trailers get a 5th tab**, shipped **last**. | The brief asks for a separate tab. It is the heaviest feature (web views, memory, feed curation) and depends on D1 and D5 being proven on film detail first. |
| D10 | **Universal links** (`35mm.contact/l/<id>`, `/p/<id>`, `/person/<id>`) are added with playlists. The domain is `35mm.contact` (bought on Vercel, 2026-09-23). Vercel also hosts the link fallback pages and the privacy policy. | "Share with friends" needs a link that opens in the app. There are no DMs, so the iOS share sheet is the channel. App Store Connect also requires a privacy policy URL, so the domain pays for itself. |
| D11 | **The Trailers tab feed comes from KinoCheck** (`/trailers/trending`, `/trailers/latest`), cached server-side. TMDB `videos` stays the source on film detail. | KinoCheck is a curated, studio-sourced "what's new" stream, which is exactly what a trailer feed needs. It is still YouTube-hosted, so D5 is unchanged. |
| D12 | **The profile Posts tab shows only the user's Explore posts.** Friend activity stays behind "Recently watched". **The home feed merges friends' Explore posts** with their activities. | This is the visibility model: Explore is the public face and activities are for friends. Friends shouldn't miss what someone posts publicly. |
| D13 | **Playlists can be posted to Explore** as a new `list` kind. Because of D12, that post also reaches friends' home feeds, and it replaces the separate "created a list" activity. | There is one publishing path and one card design, and the lists are discoverable both publicly and by friends. |

---

## 3. Build order

```
Phase 0  Foundations          ─┐  (1 week-ish, no user-visible feature on its own)
Phase 1  Film detail upgrades  ├─ Where to watch → Trailer (inline) → Cast rail
Phase 2  Person pages (read)   ┘  (tapping any face now goes somewhere)
Phase 3  Watchlist            ── lists schema lands here
Phase 4  Playlists + sharing  ── same schema, + universal links
Phase 5  Profile tabs + Explore posts in home feed + list posts on Explore
Phase 6  Follow people + alerts ── first Edge Function + cron
Phase 7  Trailers tab         ── reuses the player from Phase 1
```

### Why this order

1. **Cheap, visible wins first.** Phases 1–2 are pure TMDB reads with **no migration**, and they make film detail feel finished. Where to watch is the smallest feature on the list, so it goes first to prove the enriched detail call (D1).
2. **Build the list schema once, and start small.** The watchlist (Phase 3) is the smallest slice of D2: one system list, no titles, no covers, no sharing. It shakes out `list_items`, the "Add to…" sheet and the strike-off-then-review flow before playlists put a bigger surface on the same tables.
3. **Profile tabs wait until they have content.** Built earlier, the Lists tab would be empty. Built after Phase 4, every tab has something in it on the first day.
4. **New infrastructure comes late and is isolated.** Phase 6 introduces Edge Functions, cron and a server-held TMDB key. It is kept apart so a problem there cannot block the list and profile work.
5. **Trailers tab last.** It has the most performance risk and the least new data. By then the player (Phase 1) and person/film links (Phase 2) already exist, so it is mostly a feed and a pager.

**If you only ship one phase before the next TestFlight,** ship Phases 1–3. That is the best ratio of value to risk.

---

## 4. Feature designs

### 4.0 Phase 0 — Foundations

| Piece | Detail |
|---|---|
| **Enriched details** | `MovieRepository.getFilmDetails(id, type)` adds `append_to_response`. Movie: `videos,credits,watch/providers,release_dates`. TV: `videos,aggregate_credits,watch/providers,content_ratings`. It parses into a new `FilmExtras` (trailers, cast, crew, providers, theatrical status) held beside `FilmModel`, so the freezed model doesn't grow a dozen nullable fields. |
| **Caching** | `filmExtrasProvider.family` with `keepAlive` and a 30-minute TTL (via `ref.keepAlive()` plus a `Timer`). Provider data changes daily at most. |
| **Region** | A `regionProvider` reads `PlatformDispatcher.instance.locale.countryCode` and falls back to `US`. It can be overridden later in Settings ("Streaming region"). |
| **New packages** | `youtube_player_iframe` (brings `webview_flutter`), `url_launcher`, `share_plus`, and `app_links` (Phase 4). |
| **Person route** | `/person/:personId` goes on the root navigator, like `/film/:filmId/:mediaType`, so it can be pushed from any tab. |
| **Shared "Add to…" sheet** | The API is designed now and built in Phase 3: `showAddToListSheet(context, subject)`. |

### 4.1 Where to watch (Phase 1)

**UI.** A single row under the title block on film detail.

- Up to about 6 provider logos (TMDB `logo_path`, 28pt, rounded 7), ordered by TMDB's `display_priority`.
- They are grouped as **Stream**, then **Rent/Buy** as a quieter second group behind a "More ways to watch" disclosure.
- If theatrical status is "in theaters", an **"In theaters"** glass tag comes first.
- If there are no providers and it isn't in theaters: "Not streaming in {region} right now", in `inkTertiary`.
- Tapping the row opens a glass panel with the full list per type and a JustWatch attribution line. Tapping a provider opens TMDB's `link` (a JustWatch page) with `url_launcher`. TMDB gives no per-service deep links, so we don't fake them.

**"In theaters" logic.** For a movie, check `release_dates` in the user's region.

- **In theaters:** there is a type-3 (theatrical) date in the last 75 days **and** no type-4 (digital) date yet.
- **Coming to theaters {date}:** the type-3 date is in the future.
- TV never shows this.

**Data.** None stored. It is all read from TMDB per view.

**Risks.**

- JustWatch attribution is **required**.
- Provider data varies by region. It will look sparse outside the US, UK, CA, AU and IN, and the empty state has to read well.

### 4.2 Trailers

**Phase 1 — on film detail.**

- **Picking the trailer:** from `videos`, choose `site == 'YouTube'`, preferring `type == 'Trailer' && official`, then the newest, then any Teaser.
- **Placement:** a 16:9 glass-framed thumbnail (`img.youtube.com/vi/<key>/hqdefault.jpg`) with a play glyph, placed under the overview. Tapping it opens a full-screen `YoutubePlayer` in a modal route with native controls, dismissed by a swipe down.
- **Other videos:** if there is more than one, add a horizontal "Videos" rail (Teasers, Clips, Featurettes).

**Phase 7 — the Trailers tab.**

- **Tab:** a 5th tab, `play.rectangle.on.rectangle`, labelled **Trailers**.
- **Layout:** a vertical `PageView`, one trailer per page. The trailer is 16:9 and centred, with a blurred, poster-tinted backdrop (reusing `poster_palette.dart`) so the screen doesn't look letterboxed and empty.
- **Overlay:**
  - title, year, and the where-to-watch chips (4.1)
  - Save to watchlist, Add to list, and Open film
  - the mute toggle
- **Playback budget:**
  - **Exactly one live web view.** Pages that aren't current show the static thumbnail.
  - On settle, the current page's thumbnail cross-fades to the player. It autoplays **muted** and **inline** (`playsinline=1`, which iOS requires). A tap unmutes, and the mute state carries between pages.
  - Leaving the tab (`shellChromeVisible`/branch change) pauses and disposes the player.
- **Feed source: KinoCheck (D11), cached through Supabase.**
  - **What it is:** a free trailer API (studio-sourced, run by some.marketing GmbH). It has `/trailers/trending` and `/trailers/latest`, plus `/movies` and `/shows` lookups by TMDB id.
  - **Response:** each video comes with `youtube_video_id`, a thumbnail, a category (Trailer, Teaser, Clip, Featurette), views and publish date. The videos **live on YouTube**, so playback is the same IFrame player as film detail (D5).
  - **Why not call it from the app:** the free tier is **1,000 requests/day per client key**, and every user's app would burn through that shared budget.
  - **Caching job:** an Edge Function on `pg_cron` runs every 6 hours. It pulls trending and latest, resolves each to its TMDB id and snapshot (title, poster, backdrop, year, media type), and upserts a `trailer_feed` table. The app reads only that table. That is about 50 KinoCheck calls a day, whatever the user count.
  - **Tabs in the tab:** a "Trending / New" `GlassSegmentedControl` at the top maps straight onto the two endpoints.
  - **Fallback:** if KinoCheck is down or thin, the job backfills from TMDB `upcoming`/`now_playing` + `videos`, so the table never goes empty.
  - **Deferred:** "for you" weighting by the genres you log.
  - **Consequence:** the Trailers tab now needs the Edge Function + cron infrastructure. Phase 6 (follows) builds that first, which is one more reason the tab ships last.
  - **To confirm before building:** KinoCheck's terms on attribution and on commercial use in a free app.

**Risks.**

- **YouTube ToS and App Review:**
  - no hiding YouTube branding or controls
  - no background audio
  - no downloading
  - the IFrame player is the compliant path
- **Memory and jank:** more than one WKWebView alive in a pager is the usual failure. The single-player rule is non-negotiable, and it must be profiled on the device (burritoman), not a simulator.
- Some trailers are age-restricted or can't be embedded, and fail inside the player. Listen for the player's error event and auto-advance.

### 4.3 Person pages (Phase 2) and follows (Phase 6)

**Phase 2 — read-only person page, `/person/:id`.**

- **Data:** one call, `person/{id}?append_to_response=combined_credits,images,external_ids`.
- **Header:**
  - large circular portrait (`PillPortrait`), name, known-for department
  - birth and death, place of birth
  - a bio truncated to 4 lines, which expands on tap
- **Sections:**
  - **Known for:** the top 10 credits by `vote_count`, as a poster rail.
  - **Filmography:** a `GlassSegmentedControl` for Acting / Directing / Writing / Producing, showing only departments that have credits. Each is a year-grouped list, newest first. Upcoming titles (no date, or a future date) are pinned at the top as "Upcoming". TV credits collapse to a single row per show with an episode count.
  - **Your history with them:** "You've logged 7 of their films" plus your average rating. This comes from a query on your own `activities` against the credit ids, and is cheap because `activities.film_id` is indexed.
- **Entry points (all new taps):**
  - a cast/crew rail on film detail (from `credits` in D1)
  - favorite actors/directors on profiles
  - search results (people are already searchable)
  - Explore subject chips, later

**Phase 6 — following people.**

```sql
create table public.person_follows (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  person_id    int  not null,
  person_name  text not null,          -- snapshot, like film_title elsewhere
  profile_path text,
  department   text,
  created_at   timestamptz not null default now(),
  primary key (user_id, person_id)
);
-- RLS: readable by authenticated (follows are public, like favorites); own write.

create table public.person_credit_snapshots (   -- server-only; no client policies
  person_id   int primary key,
  credit_keys text[] not null,         -- '{movie:123:cast, tv:456:crew:Director}'
  checked_at  timestamptz not null
);
```

- **Follow vs Favorite.**
  - **Favorite** is a curated, ranked profile showcase that stays as it is.
  - **Follow** is a subscription.
  - A person page shows both actions: "Follow", plus an overflow menu item "Add to favorite actors".
- **Alerts:**
  - An Edge Function `person-watch` runs daily via `pg_cron` + `pg_net`. For each `distinct person_id` in `person_follows`, it fetches `combined_credits`, diffs it against the snapshot, and inserts notifications for followers when there are new credits.
  - The notification type is `personNewCredit`: "Florence Pugh is in *Project Hail Mary*", with the poster.
  - The **first run for a person only writes the snapshot**, so following someone never floods you.
  - The TMDB key moves into function secrets for this.
- **Cost:** one TMDB call per followed person per day, with the function chunked at about 40 req/s. That is fine up to many thousands of distinct followed people.
- **Surface:** a "New from people you follow" rail at the top of the Trailers tab or Explore. Which one is decided at Phase 6.

**Migration gotcha.** Run `alter type notification_type add value 'personNewCredit'` **on its own**. Postgres won't let the new value be used in the same transaction. Put it in its own migration file (`007a_…`), as we should have for any enum change.

### 4.4 Lists: watchlist (Phase 3) and playlists (Phase 4)

**Schema (migration 006).**

```sql
create table public.lists (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  kind         text not null check (kind in ('watchlist', 'playlist')),
  title        text check (char_length(title) between 1 and 80),
  description  text check (char_length(description) <= 500),
  visibility   text not null default 'public'
               check (visibility in ('public', 'friends', 'private')),
  item_count   int  not null default 0,            -- trigger-kept
  save_count   int  not null default 0,            -- trigger-kept
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint playlist_has_title check (kind = 'watchlist' or title is not null)
);
create unique index lists_one_watchlist on public.lists (user_id) where kind = 'watchlist';
create index lists_user_idx on public.lists (user_id, updated_at desc);

create table public.list_items (
  list_id          uuid not null references public.lists(id) on delete cascade,
  film_id          int  not null,
  media_type       text not null check (media_type in ('movie', 'tv')),
  film_title       text not null,
  film_poster_path text,
  film_backdrop_path text,
  film_year        text,
  position         double precision not null,       -- fractional index, see below
  note             text check (char_length(note) <= 280),
  watched_at       timestamptz,                     -- watchlist only
  added_at         timestamptz not null default now(),
  primary key (list_id, film_id, media_type)
);
create index list_items_order_idx on public.list_items (list_id, position);

create table public.list_saves (                    -- "follow" someone's playlist
  list_id  uuid not null references public.lists(id) on delete cascade,
  user_id  uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
```

- **RLS.** Select is allowed when `visibility = 'public'`, or when you're the owner, or when `visibility = 'friends'` and there is an accepted friendship. Put that check in one `security definer` helper, `can_view_list(list)`, so the three tables share it. Items inherit visibility through their list. Only the owner writes.
- **Triggers:**
  - `item_count` and `save_count` counters
  - `updated_at` is touched on item changes, so the profile orders lists by recent activity
  - a **`profiles` insert trigger creates the watchlist**, and a one-off backfill covers existing users. The client never has to handle a missing watchlist.
- **Ordering.** `position` is a fractional index. An insert at the end is `max + 1`. A drag between a and b is `(a + b) / 2`. When the gap gets smaller than 1e-9, renumber the list with an RPC. Every reorder is a single-row update.

**Watchlist UX (Phase 3).**

- **Adding:**
  - A **bookmark** `NativeGlassButton` on film detail. It is a one-tap toggle into the watchlist.
  - A long press, or a secondary "…" action, opens **Add to…**, which lists Watchlist first, then your playlists, then "New playlist".
  - The same actions appear on Explore subject chips, search rows and trailer pages.
- **Where it lives:** Profile → Lists tab → a pinned **Watchlist** row at the top, before Phase 5 exists as a header link. It opens `/lists/:id`.
- **Striking off:**
  - Swipe right, or tap the circle, to mark it watched. The row animates a strike-through, then settles into a collapsed **"Watched (n)"** section at the bottom. It stays there rather than being deleted, which gives an undo and a "watched from my watchlist" count for a badge.
  - Right after the strike, a glass panel titled **"You watched *Dune: Part Two*"** offers **Log it**, **Review it**, **Post to Explore** and **Not now**:
    - **Log it** opens the existing post flow in watched-only mode, prefilled.
    - **Review it** opens the post flow with rating focused.
    - **Post to Explore** opens `showExploreComposer(subject: …, kind: review)`.
  - In reverse: logging or reviewing a film that is on your watchlist **auto-strikes it**. This is done by a DB trigger on `activities` insert that sets `watched_at`. It keeps the two in sync even when a review is posted from somewhere else.
- **Visibility:** the watchlist defaults to **public**, as on Letterboxd. The list's menu offers a switch to friends or private.

**Playlists UX (Phase 4).**

- **Create:**
  - Title, optional description and visibility, in a glass panel. The live 2×2 cover preview updates as you type, which is the fun moment.
  - Then an empty-state "Add films" opens a multi-select search (reusing `MediaResultRow` from `subject_picker.dart`).
- **Cover (D4):** `PlaylistCover(items.take(4))`.
  - 4 items: a 2×2 poster mosaic.
  - 1–3 items: a lead poster over a blurred version of itself.
  - 0 items: a glass tile with a `music.note.list`-style glyph (`film.stack`).
  - It renders at any size, so the same widget covers the profile grid, the list header and share previews.
- **List screen:**
  - A large cover on the header with a blurred-cover ambient background (the `_Ambient` pattern from Explore), then the title, author, "n films · updated 2d" and the description.
  - Action pills: Save (others' lists) or Edit (yours), Share, and Shuffle, which picks a random film with a playful spin and fits what a playlist is for.
  - Rows show the poster, title, year, your rating if you've logged it, and the optional note.
  - Edit mode supports drag reorder and swipe delete.
- **Sharing (D10):**
  - Share opens `share_plus` with `https://35mm.contact/l/<list-id>`. Needs:
    - an Associated Domains entitlement `applinks:35mm.contact`
    - an `apple-app-site-association` file on the domain (a static file in a small Vercel project)
    - `app_links` to route into go_router
    - a tiny static fallback page ("Open in 35mm / Get it on the App Store")
  - Link previews in iMessage want an `og:image`. v1 ships a static branded image. v2 renders the 2×2 cover with an Edge Function and `og_edge` or satori, and caches it in Storage. That is the only place a server-rendered cover is ever needed.
- **Posting a playlist to Explore (D13):**
  - A new `ExploreKind.list` ("List", `rectangle.stack`), with a nullable `list_id` column on `explore_posts` (`references lists(id) on delete cascade`).
  - Constraints: a `list` post needs `list_id` and has no film subject. Its body is an optional caption (≤500), and the list must be `public` when posted.
  - The Explore card draws the `PlaylistCover` mosaic with the title, "n films · by @user" and the caption, and taps through to the list screen. Likes work as usual. `allowsComments` stays true, since a list invites "you forgot X".
  - `explore_feed` joins the list title, item count and first-4 posters, so the card renders without a second query.
  - If the list later goes private, the view hides the post (the join filters on `visibility = 'public'`). Deleting the list deletes the post.
  - **Entry points:** a "Share to Explore" toggle when creating a public playlist (default on), a "Post to Explore" item in the list screen's menu, and a "List" kind tile in the composer that opens a picker of your public lists.
  - Because friends' Explore posts appear on home (4.6), this is also how friends see new lists. There is no separate "created a list" activity.
- **Deferred:** collaborative playlists, playlist comments, episodes as items (title-level only for v1), and custom cover upload.

### 4.5 Profile tabs (Phase 5)

**Structure.** A `CustomScrollView` with these pieces in order:

1. the header (avatar, name, stats, Edit/Follow): unchanged
2. `SliverPersistentHeader(pinned: true)` holding a **`GlassSegmentedControl`** with SF-symbol segments:

| Tab | Symbol | Content |
|---|---|---|
| Posts | `text.bubble` | **Only the user's Explore posts** (D12), as a single-column list of `ExplorePostCard`s, newest first. A kind filter (the Explore chips) appears once there are more than 10. Friend activity stays behind **Recently watched** in the header, and the old activities grid moves there. |
| Lists | `rectangle.stack` | Watchlist pinned first, then playlists as a 2-column grid of covers. The owner sees "New playlist" as the first tile. |
| Favorites | `star` | Top 3, Favorite Actors and Favorite Directors: the existing sections moved as they are, with portraits now tappable to person pages. |
| Badges | `rosette` | All badges in a 3-column grid. Earned ones are lit and show the date. Locked ones are dimmed and show progress ("12 / 25 reviews"). Tapping opens a glass detail panel. |

- **Mechanics:**
  - The tab state lives in a `StateProvider.family<ProfileTab, String userId>`.
  - Each tab builds its own sliver list. Switching remembers each tab's scroll offset, restoring it with `jumpTo` after the header clamps.
  - A horizontal swipe on the content changes tabs (a `GestureDetector` with a velocity threshold), not a `TabBarView`. `TabBarView` fights the single scroll view and the pinned header.
- **Code:** `profile.dart` splits into `profile/profile_screen.dart`, `profile_header.dart`, `tabs/posts_tab.dart`, `lists_tab.dart`, `favorites_tab.dart` and `badges_tab.dart`.
- **Badges:**
  - Add list-related badges now that they're possible:
    - **Curator:** first public playlist
    - **Tastemaker:** a playlist saved by 10 people
    - **Clean Slate:** 10 watchlist strike-offs
  - Move badge **award** logic server-side into triggers as part of this phase. The client-computed `BadgeService` can be spoofed and misses events that happen on other devices.

### 4.6 Explore posts in the home feed (Phase 5)

The home feed (friends) shows friends' **Explore posts**, interleaved by time with their activities.

- **Query:** a `home_feed` view that is a `union all` of two thin projections, `('activity', id, user_id, created_at)` from `activities` and `('explore', id, user_id, created_at)` from `explore_posts`, filtered to the viewer plus accepted friendships. It is **keyset-paginated** on `(created_at, id)`, not by offset, because two tables growing underneath offset pages would duplicate and skip rows.
- **Hydration:** the client takes a page of refs, then batch-loads the rows from `feed_activities` and `explore_feed` with two `in (...)` queries, and zips them back in order.
- **Card:** Explore items reuse `ExplorePostCard` in a slightly slimmer "on home" variant with a small "Posted on Explore" globe kicker, so it is clear the post is public. Likes, votes and comments share the same providers, so state matches between Home and Explore.
- **Your own Explore posts** show up in your home feed too, the same way your own activities already do.
- **Why a view and not a client-side merge of two paged streams:** a client merge needs a k-way merge with two cursors and breaks on refresh. The view keeps the one-cursor pagination the home feed already has.

---

## 5. Cross-cutting concerns

| Concern | Decision |
|---|---|
| **TMDB rate limits** (~50 req/s per IP, no daily cap) | Enriched details (D1) and provider caching keep film detail at 1 request. The trailer feed fetches 2 pages ahead, never more. Server jobs throttle to ≤40 req/s. |
| **Attribution (App Review)** | TMDB (already required), plus **JustWatch** on where-to-watch. YouTube branding stays visible in the player. |
| **Moderation** | Playlist titles and descriptions are user text shown publicly. Reuse `content_reports` by adding a nullable `list_id` next to `post_id`, with a check that exactly one is set, and use the existing report reasons panel. Guideline 1.2 requires this for UGC. |
| **Migrations** | `008_lists.sql` (Phase 3–4), `009_profile_badges.sql` (Phase 5), `010_home_feed_and_list_posts.sql` (Phase 5: `home_feed` view, `explore_posts.list_id`, `list` kind), `011a_person_follow_enum.sql` + `011_person_follows.sql` (Phase 6), `012_trailer_feed.sql` (Phase 7). Numbered after ADR 0002's `006` and `007`. The user pastes each one, as before, and each is idempotent and safe to re-run. |
| **Notifications** | New types: `personNewCredit` (P6) and `listSaved` (P4, optional). Each enum add goes in its own file. |
| **Offline and failure** | All TMDB-only sections hide on error, like friends' reviews already do. List writes are optimistic with rollback and a toast, the same pattern as Explore votes. |
| **Testing** | Unit tests: `FilmExtras` parsing (fixtures of real TMDB responses), theatrical status inference, fractional-index renumbering, and `CommentThreads`-style grouping for the filmography. Everything else is checked on the device. |
| **Performance targets** | Film detail's first meaningful paint must not regress (extras render progressively below the fold). The Trailers tab holds 60fps paging with ≤1 web view on an iPhone 13-class device. |

---

## 6. Alternatives considered

| Option | Rejected because |
|---|---|
| **Separate `watchlist` table** instead of `lists.kind = 'watchlist'` | It duplicates the item model, the covers, the "Add to…" sheet and RLS. The only watchlist-specific column (`watched_at`) is nullable and harmless on playlists. |
| **Server-generated collage image for playlist covers** | It goes stale on every reorder, needs a worker and costs storage. It is only needed for link previews, and it is deferred to exactly that. |
| **Native AVPlayer for trailers** | There is no licensed MP4 source. YouTube stream extraction breaks ToS and gets rejected. |
| **Launching the YouTube app for trailers** | Acceptable only as a fallback. It leaves the app, and a scrollable trailer tab is impossible that way. |
| **Trailers as a segment inside Explore** instead of a tab | This was viable, and it avoids a 5th tab. It was rejected because the brief asks for a separate tab, and mixing a video pager with a text feed muddles both. Revisit if 5 tabs feel crowded. |
| **Client-side polling for followed people's new work** | It only runs while the app is open. It can't notify, and it multiplies TMDB calls per user instead of per person. |
| **`TabBarView` for profile tabs** | Nested scrolling with a pinned header over a `TabBarView` is the classic Flutter pain point (it needs NestedScrollView plus overlap injectors, and scroll positions desync). A single scroll view with swapped slivers is simpler and matches the glass header. |
| **Third-party availability APIs** (Watchmode, Streaming Availability) | They are paid, need another key, and give deeper links. Revisit only if per-service deep links become a priority. |

---

## 7. Product questions

### Resolved (2026-09-23)

1. **The profile Posts tab shows Explore posts only.** Friends see activity through Recently watched. The home feed also shows friends' Explore posts (D12, 4.6).
2. **The watchlist is public by default,** with a friends or private toggle (4.4).
3. **Playlists reach friends via the home feed, and they can be posted to Explore** (D13). One mechanism covers both.
4. **Domain:** `35mm.contact`, bought on Vercel (D10). It is needed for:
   - universal links that open shared lists and posts in the app
   - the iMessage link preview
   - a web fallback for people without the app
   - the privacy policy and support URLs that App Store Connect requires anyway

   A free `*.vercel.app` subdomain works technically as a stopgap.

### Open

5. **Trailer tab audio.** Autoplay is muted, with tap to unmute that is then remembered. Confirm, because TikTok-style unmuted autoplay is not allowed for embedded YouTube on iOS without a user gesture anyway.

---

## 8. TODO — `35mm.contact` web presence

A small Vercel project (its own repo, e.g. `35mm-web`) serves everything on the domain. Items 1–2 are needed for App Store submission whatever the phase. Items 3–5 are needed before Phase 4 sharing ships.

- [x] **1. Connect the domain.** *(Done 2026-09-23. The site is live from repo `khushnaidu/35mm`. The apex now serves directly with no redirect, which Apple needs when fetching the association file for `applinks:35mm.contact`.)* Point `35mm.contact` at the Vercel project, and redirect `www.35mm.contact` to the apex. Check that HTTPS works on both.
- [x] **2. `/privacy` and `/support` pages.** *(Pages done. Still to do: email forwarding for `support@35mm.contact` and entering both URLs in App Store Connect.)*
  - The privacy policy covers what we store:
    - Supabase account data, posts, lists, voice notes and photos
    - TMDB, KinoCheck and JustWatch data we show but don't collect
    - account deletion
  - The support page gives a contact email and FAQs.
  - Add both URLs in App Store Connect.
- [ ] **3. `/.well-known/apple-app-site-association`.**
  - App ID: Team ID **`L6YHMZPSYT`** (from the Xcode signing config) and bundle ID `com.cinemon.app`, giving `L6YHMZPSYT.com.cinemon.app`.
  - Serve it as `application/json` with no redirects and no file extension. Set this with `headers` in `vercel.json`.
  - Covers the paths `/l/*`, `/p/*` and `/person/*`.
- [ ] **4. App side.**
  - Add the Associated Domains entitlement `applinks:35mm.contact` in Xcode, and enable Associated Domains on the App ID.
  - Add the `app_links` package and route incoming links into go_router: `/l/:id` goes to the list, `/p/:id` to the Explore post, and `/person/:id` to the person page.
  - Test on the device (burritoman) by tapping a link in Notes or Messages. Universal links don't fire when a link is typed into Safari.
- [ ] **5. Fallback pages for people without the app.**
  - `/l/[id]`, `/p/[id]` and `/person/[id]` show a branded "Open in 35mm / Get it on the App Store" page. The App Store button can be added once there's an App Store listing.
  - Each page has `og:title`/`og:image` tags for iMessage previews:
    - v1 uses a static branded image
    - v2 draws the playlist's 2×2 cover with an OG-image function (§4.4)
  - Public list and post metadata is read from Supabase with the anon key. That needs `to anon` select policies limited to `visibility = 'public'` (lists) and to all Explore posts. Add them in migration 006/009, because today's policies are `to authenticated` only.

---

## 9. Consequences

**Positive**

- Film detail becomes the hub: watch, trailer, cast, save and log, all from one request.
- One list system powers three surfaces: the watchlist, playlists and the profile Lists tab.
- The first server-side job infrastructure (Edge Functions + cron) arrives in a contained feature. It then unlocks server-side badges, a curated trailer feed, and later push notifications.

**Negative / costs**

- Four new packages. `webview_flutter` is the heavy one: binary size goes up by about 1–2 MB, and it brings WKWebView memory behaviour we have to manage.
- The TMDB key has to exist server-side too, which means two places to rotate it.
- Universal links need a domain and a hosted file. That is small, but it is infrastructure outside this repo.
- The profile rewrite touches the most-viewed screen, so it needs a careful device pass (burritoman) for regressions in the Follow/Accept flows.
