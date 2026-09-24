# ADR 0003 — Share cards: posts as Instagram stories

- **Status:** Accepted. Phases 1–4 built 2026-09-24. Later items (animated stories, Wrapped, J1) are still open.
- **Date:** 2026-09-24
- **Scope:** Turning 35mm posts, Top 3s, profiles, months and playlists into story images people post to Instagram (first), Facebook, and anywhere the iOS share sheet reaches
- **Related:** ADR 0001 D10 (universal links on `35mm.contact`). ADR 0002 (no analytics, permissions only on use).
- **Design reference:** the settled mockups, <https://claude.ai/artifact/2o9zMSpYR8UT6UJGX2rYvh> (version 3). The source is in `docs/design/share-cards-mockup.html`; image and font data are left out, so it needs the artifact to render properly.

---

## 1. Context

Sharing is how 35mm spreads. Someone sees a friend's story, likes how it looks, and taps through to make their own. The bar is Spotify's song share and year-end Wrapped: the card has to look good enough to post for its own sake.

Today the only share in the app is a playlist's link, sent through the iOS share sheet (`playlist_screen.dart`). No post can be shared as an image.

## 2. The settled set

Two rounds of mockups with the owner produced this set. Codes are the ones used in the mockups and in code.

| Code | Card | Mode | For | Notes |
|---|---|---|---|---|
| S0 | Share sheet | App screen | Everything | Swipe through styles, choose a poster-derived background colour, then Instagram story · Facebook story · Snapchat · Messages · Copy link · Save image · Other |
| H1 | Headline | Full story | Hot take | The in-app take card, full screen: blurred poster, big take, vote split, subject chip |
| H2 | Marquee | Full story | Hot take | Letterboard lettering inside a ring of bulbs |
| H3 | Sticker | Sticker | Hot take | The post as a movable card on a poster-colour gradient |
| R2 | Poster and verdict | Full story | Review | Poster glowing in its own colour, stars, one line of the review |
| R3 | Film strip | Full story | Review | Three TMDB stills on a strip of 35mm negative with edge codes |
| E1 | Episode card | Full story | Episode review | The in-app episode card front, lifted out |
| E2 | Full-bleed still | Full story | Episode review | The still full screen; show and episode in plain Helvetica with no bands |
| C1 | Cover | Full story | Critique | Magazine cover: still, serif headline, standfirst, byline |
| C2 | Pull quote | Full story | Critique | One sentence from the critique, chosen by the author |
| T1 | Podium | Full story | Top 3 | The profile's Top 3, with the same orb and badge art (`assets/top3elements`) |
| T2 | Contact sheet | Full story | Top 3 | Three strips, number one circled in grease pencil |
| P1 | Profile | Full story | Profile | Arch photo, Siberian username, Isometric counts, a large Top 3, and a "Follow me on 35mm" pill |
| P2 | Month in film | Full story | Profile / month | Big count, the month's posters, four facts. **Also wanted in the app itself** (§6) |
| L1 | Playlist | Full story | Playlist | Spotify-style: 2×2 cover, title, creator, description, first three films |

**Cut:** R1 (the ticket stub, which read as generic), the first-round T1, P1 and the receipt version of P2, and J1 (the Polaroid for "just watched", deferred).

**Branding:** every card shows the 35MM mark and the word **35mm**. No URL goes on the card: the link travels in Instagram's link sticker (§3.3).

## 3. Decisions

### D1 — Cards are Flutter widgets, rendered on the device

Every card is an ordinary widget laid out on a fixed **360 × 640** logical canvas, and all sizes are written in canvas units, so 1 unit is 1% of the width, as in the mockups' `cqw`. To export, a `RepaintBoundary` is captured at `pixelRatio: 3`, giving **1080 × 1920** PNGs.

- **Why:** there's no server to run, the output is identical to the preview, it works offline, and the same widgets can appear inside the app (P2). A server renderer would need a headless browser and a hosting bill, and would be a second implementation of every design.
- The preview in S0 is the capture target itself, scaled down with `FittedBox`. `toImage` captures the boundary in its own coordinates, so the scaling doesn't change the export.
- Images (posters, stills, the avatar) are loaded through the same `CachedNetworkImage` cache and awaited before capture, so a card is never exported half loaded.

### D2 — Instagram and Facebook through their story URL schemes, with our own small iOS channel

- **Instagram:** `instagram-stories://share?source_application=<Meta App ID>`. The pasteboard gets the item keys `com.instagram.sharedSticker.backgroundImage` (full-story cards) or `…stickerImage` plus `…backgroundTopColor` and `…backgroundBottomColor` (sticker cards), and expires in 5 minutes.
- **Facebook:** `facebook-stories://share?source_application=<Meta App ID>`, using the matching `com.facebook.sharedSticker.*` keys and `com.facebook.sharedSticker.appID`.
- **The channel** is `MethodChannel('app.35mm/story_share')` in `AppDelegate.swift`, about 80 lines. It has these methods:
  - `canShare(target)`
  - `share(target, background?, sticker?, topColor, bottomColor)`
  - `saveImage(png)`
- **Snapchat** (added after Phase 4): Creative Kit Lite, no SDK. `snapchat://creativekit/preview/1?checkcount=<pasteboard change count>&clientId=…&appDisplayName=35mm`, with `com.snapchat.creativekit.clientID`, `…backgroundImage` (the full 9:16 card, sticker styles included) and `…captionText` (the link, `?s=sc`) on the pasteboard. The client ID is the dart define `SNAP_CLIENT_ID`; without it the button is hidden. Snap only lets registered demo users share until the app is approved in Snap's developer portal.
- **Messages** (added after Phase 4): `MFMessageComposeViewController` with the card attached and the link (`?s=msg`) as the text, shown only when the phone can send attachments. The sheet closes on send and stays open on cancel.
- **Copy link** copies the link with `?s=copy`. **Other** (was More) is the system share sheet, which covers WhatsApp, Instagram DMs, Mail and AirDrop. None of those take an image from another app any other way.
- **Why not a plugin:** the Flutter plugins for this (`social_share`, `appinio_social_share`) are thinly maintained, and each pulls in far more than two URL schemes. We own 80 lines instead.
- **The Meta App ID** comes in as a dart define, `META_APP_ID`, in `dart_defines.json`. If it's missing, or Instagram isn't installed, the Instagram and Facebook buttons are hidden and Save and More remain.
- **Info.plist changes:**
  - `LSApplicationQueriesSchemes` gets `instagram-stories` and `facebook-stories`.
  - `NSPhotoLibraryAddUsageDescription` is added for Save. That permission is requested only on first save, which keeps ADR 0002's "only when you use the feature".

### D3 — The link: Instagram's link sticker, with the URL offered alongside

Only Instagram's partner apps get an automatic link on the story. Everyone else relies on the poster adding a link sticker. So:

- The item we put on the pasteboard for Instagram also carries the post's universal link as `public.url` and `public.utf8-plain-text`. If Instagram leaves those in place, the link sticker's paste field picks it up. **This is an experiment to verify on the device.** If it doesn't work, S0 shows "Link copied, add it with the link sticker" after the story opens, and copies the link a moment later, once Instagram has read its items.
- **Links (ADR 0001 D10):**
  - `/l/<id>` for playlists, which existed already.
  - `/p/<id>` for Explore posts: takes, critiques and Explore reviews.
  - `/u/<username>` for profiles, Top 3s, months, and **logged reviews**.
  - The planned `/a/<id>` was dropped (revised 2026-09-24). A logged review is friends-only, so a stranger opening it from a story would hit a wall; the author's profile is the page that works for everyone.
  - Open Graph images per post were also dropped for now. Rendering one needs to read the post without signing in, and `explore_posts` is readable by signed-in users only. Link previews use the brand image until that changes.

### D4 — One share entry point, fed by a `ShareSubject`

A sealed `ShareSubject` describes what is being shared:

- `TakeShare(ExplorePost)`
- `ReviewShare`, built from an `ActivityModel` or a review `ExplorePost`
- `EpisodeShare`
- `CritiqueShare(ExplorePost)`
- `Top3Share(user, films)`
- `ProfileShare(user)`
- `MonthShare(user, month)`
- `PlaylistShare(list)`

Each subject lists its templates in order, and the first is the default. `showShareSheet(context, subject)` is the only way in.

**Where Share appears:**

- **Explore post:** a Share row at the top of the ••• menu, for takes, reviews and critiques.
- **Feed card:** a share glyph on the back of review cards, next to the react and comment counts.
- **Own profile:** Share in the header: P1, P2, then T1 and T2 for your Top 3 films and for your Top 3 shows.
- **Playlist:** the existing share button opens S0 (L1). "Copy link" stays in More.

### D5 — Fonts are bundled, and only the ones the settled cards use

| Face | Used by | Source |
|---|---|---|
| San Francisco (system) | Most cards | iOS |
| Helvetica Neue (system) | E2, P2, L1, P1 text | iOS, used as `fontFamily: 'Helvetica Neue'` |
| Instrument Serif (regular, italic) | C1, C2 | Google Fonts, OFL |
| IBM Plex Mono (500, 600) | C1 byline, R3 edge codes | Google Fonts, OFL |
| Big Shoulders Display (700, 900) | H2 | Google Fonts, OFL |
| Reenie Beanie | T2 | Google Fonts, OFL |
| Siberian, 3D Isometric | P1 | Already in `assets/` |

Fonts go in `assets/fonts/share/`, with each licence file next to them.

### D6 — Colour comes from the poster

The sticker gradient, S0's swatches, R2's glow and P2's wash all come from `PosterPalette` (`core/utils/poster_palette.dart`), which the review card already uses. The swatches are `primary`, `secondary`, black and warm white. On full-story cards a swatch changes the background wash, not the artwork.

### D7 — No tracking beyond counting link hits

ADR 0002 promises no analytics. The only measure of sharing we allow ourselves is anonymous hit counts on `35mm.contact` links carrying `?s=ig` or `?s=fb`, logged by the website host. We store nothing per user, and the app sends nothing.

## 4. Build order

| Phase | Ships | Needs |
|---|---|---|
| **1. Engine and the first cards** | Canvas and units, capture, the iOS channel, S0, Save and More, then Instagram and Facebook once the App ID is in. Cards: **H1, H3, R2, E1**. Entry points on Explore posts and feed review cards. | Meta App ID for the story buttons; everything else works without it |
| **2. Themed cards** | **H2, R3, E2, C1, C2, T2, T1**. Bundled fonts. R3 and T2 fetch stills from TMDB `/{movie,tv}/{id}/images` at share time. C2's sentence picker. | — |
| **3. Profile, month, playlist** | **P1, P2, L1**. A month-stats query: count, runtime and genres from `activities`, with runtime and genres filled in from TMDB details and cached. **Month in film inside the app** as a profile card (§6). | — |
| **4. Links** | `/p/` and `/u/` routes in the app, and fallback pages on the website (`khushnaidu/35mm`) | Website repo |
| **Later** | Animated stories (grain, flicker, strip roll) as MP4 through `backgroundVideo`. Wrapped as its own ADR, aimed at December. The J1 Polaroid. | — |

**Progress:**

- **Phase 1:** built 2026-09-24. Share appears on Explore takes and reviews (••• → Share) and on your own feed reviews. Instagram and Facebook stories confirmed working on device 2026-09-24 with the Meta app ID in `dart_defines.json`.
- **Phase 2:** built 2026-09-24.
  - Critiques join the ••• menu.
  - Top 3 cards (T1, T2) for films and shows are in the profile's share carousel after P1 and P2 (moved 2026-09-24; there's no separate Share pill on the shelf).
  - The C2 sentence is chosen with the arrows under the swatches.
  - Stills come from `filmStillsProvider`.
- **Phase 3:** built 2026-09-24.
  - P1 and P2 are behind a Share button in your own profile's top bar.
  - A **Month in film** tile sits under your profile header (own profile, months with logs only). It opens the full P2 card with a Share button.
  - A playlist's Share now opens L1, falling back to the plain link when the playlist is empty.
  - Month stats come from `monthInFilmProvider` (`lib/share/month_stats.dart`): your logs for the month, TMDB runtime, genres and directors (6 lookups at a time, cached), and the month's most-voted take. `buildMonthInFilm` is pure and unit-tested.
- **Phase 4:** built 2026-09-24.
  - The app routes `/p/<id>` to the post and `/u/<username>` to the profile (`lib/share/shared_link_screens.dart`).
  - The website adds both paths to `apple-app-site-association` and rewrites them to the `/open` fallback page.
  - The privacy page describes share cards and the add-only Photos permission.
  - Nothing was built for the `?s=` counts: Vercel's request logs already record them, and D7 allows nothing more.
- **Share targets:** built 2026-09-24. Snapchat, Messages and Copy link join the row, which now scrolls sideways; More is renamed Other. X gets no button of its own; it's reachable through Other.
- **Checking the cards:** `test/share_cards_preview_test.dart` renders every card to PNG from local art (it's skipped unless `SHARE_PREVIEW_ART` and `SHARE_PREVIEW_OUT` are set).

## 5. Risks

- **Instagram changes the scheme.** It has done so once, when it required the App ID in 2023. The channel is small and isolated, and Save plus More always work.
- **The link experiment (D3) fails.** Then we fall back to the "Link copied" prompt. The card is branded either way.
- **Image rights.** Posters and stills are TMDB-sourced studio artwork, used the same way Letterboxd uses them. Each card carries a small "TMDB" credit in the corner, as TMDB's terms ask.
- **Capture before images load.** D1 awaits every image the card uses. A card with a missing poster renders its placeholder rather than blocking.

## 6. Cards inside the app

Because cards are widgets, any of them can appear inside the app at no extra cost. The owner wants **Month in film (P2)** in the app first. It's planned for Phase 3 as a card on your own profile, with that month's stats and a Share button on it. Others (C1 as a critique header, R3 on film pages) can follow once they've proved themselves as share cards.
