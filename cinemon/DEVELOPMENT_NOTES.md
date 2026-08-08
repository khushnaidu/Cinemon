# Cinemon Development Notes

## Current Status: Phase 3 In Progress (Profile Setup Complete)

### What's Been Built

#### Phase 1: Core Setup & Authentication
- Supabase integration (Auth, Postgres, Storage) — migrated off Firebase 2026-08-08
- Custom animated splash screen using `background.gif`
- Login/Signup screens with gradient background (black to dark purple)
- GoRouter navigation with auth guards
- Riverpod state management

#### Phase 2: TMDB Integration & Home Feed
- **TMDB API Integration**
  - API key configured in `lib/core/constants/api_constants.dart`
  - Movie/TV search with debounced input
  - Trending movies endpoint
  - Poster and backdrop image URL helpers

- **Data Models** (`lib/models/`)
  - `FilmModel` - TMDB movie/TV show data (Freezed)
  - `ActivityModel` - Feed posts (watched/reviewed)
  - `FriendshipModel` - Mutual follow relationships
  - `UserModel` - User profiles

- **Repositories** (`lib/repositories/`)
  - `MovieRepository` - TMDB API calls via Dio
  - `FeedRepository` - activities, likes, reactions, comments
  - `FriendshipRepository` - Friend request management
  - `UserRepository` - User profile operations

- **Providers** (`lib/providers/`)
  - `movie_provider.dart` - Search, trending movies
  - `feed_provider.dart` - Home feed, create/delete activities
  - `friendship_provider.dart` - Friend lists, requests
  - `auth_provider.dart` - Authentication state

- **Screens**
  - `HomeFeedPage` - Vertical swipe feed with flip card animation
    - Shows poster on front, rating/review on back
    - Pull-to-refresh support
    - Loading shimmer, empty state, error handling
  - `PostPage` - Post a watch/review
    - TMDB search with 400ms debounce
    - Trending movies grid
    - Bottom sheet for rating (1-5 stars) and review text
  - `ProfilePage` - Basic profile view (needs expansion)

#### Phase 3: Profile Setup (In Progress)
- **Profile Setup Screen** (`lib/screens/auth/profile_setup_screen.dart`)
  - Appears after signup for new users
  - Username input with real-time availability check (debounced)
  - Profile photo picker with Supabase Storage upload
  - Optional bio field (150 char limit)
  - Visual feedback for username validation (green check/red X)

- **User Provider** (`lib/providers/user/user_provider.dart`)
  - `userRepositoryProvider` - UserRepository instance
  - avatar uploads go through `UserRepository.uploadAvatar`
  - `isProfileCompleteProvider` - Check if user has completed setup
  - `currentUserProfileProvider` - Stream current user's profile
  - `profileSetupControllerProvider` - Manages setup flow state

- **Router Updates** (`lib/core/routes/app_router.dart`)
  - Added `/profile-setup` route
  - Async redirect logic checks profile completion
  - New users redirected to profile setup before accessing app
  - Users with complete profiles bypass setup screen

### Architecture Overview

```
lib/
├── core/
│   ├── constants/
│   │   └── api_constants.dart    # TMDB config
│   └── routes/
│       └── app_router.dart       # GoRouter setup
├── models/
│   ├── activity_model.dart       # Feed posts
│   ├── film_model.dart           # TMDB movies/TV
│   ├── friendship_model.dart     # Friend relationships
│   └── user_model.dart           # User profiles
├── providers/
│   ├── auth/
│   │   └── auth_provider.dart
│   ├── feed/
│   │   └── feed_provider.dart
│   ├── friendship/
│   │   └── friendship_provider.dart
│   ├── movie/
│   │   └── movie_provider.dart
│   └── user/
│       └── user_provider.dart
├── repositories/
│   ├── feed_repository.dart
│   ├── friendship_repository.dart
│   ├── movie_repository.dart
│   └── user_repository.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── profile_setup_screen.dart
│   ├── edit_profile_screen.dart
│   ├── homefeed.dart
│   ├── post.dart
│   ├── profile.dart
│   ├── search_users_screen.dart
│   └── splash_screen.dart
└── main.dart
```

### Database Schema (Postgres / Supabase)

Full DDL lives in `supabase/schema.sql` — idempotent, safe to re-run.
Project ref: `juarrrjrlxsymrxvsdcu`.

```
profiles                      -- was `users`; id == auth.users.id
  id uuid PK, email, username (unique, case-insensitive)
  display_name, photo_url, bio
  badge_ids text[], favorite_genres text[]
  favorite_film_ids/actor_ids/director_ids int[]
  review_count, follower_count, following_count   -- trigger-maintained
  created_at

activities
  id uuid PK, user_id -> profiles
  activity_type ('watched'|'reviewed'), film_id, film_title,
  film_poster_path, film_backdrop_path, film_year, media_type,
  rating numeric(2,1), review_text, comment_count, created_at

activity_likes      (activity_id, user_id) PK
activity_reactions  (activity_id, user_id) PK + sticker_id
comments            id, activity_id, user_id, content, created_at
friendships         id, sender_id, receiver_id, status, accepted_at
                    unique(sender_id, receiver_id); MUTUAL once accepted
notifications       id, recipient_id, actor_id, type, activity_id, is_read
```

Badges and stickers are hardcoded client-side constants — no tables.

**`feed_activities` view** is what the app reads for feeds. It joins the
author's live username/photo (so profile edits propagate everywhere) and
aggregates likes into a `text[]` and reactions into a `jsonb` map, matching
ActivityModel's shape exactly. Writes go to the `activities` table.

### Triggers (server-authoritative — never write these from the client)

| Trigger | Does |
|---|---|
| `on_auth_user_created` | Creates the `profiles` row at signup from username metadata |
| `activities_review_count_trg` | Maintains `profiles.review_count` |
| `comments_count_trg` | Maintains `activities.comment_count` |
| `friendships_count_trg` | Maintains follower/following counts (both users, both counters) |

### Indexes

No manual console step — every index is in `schema.sql`, including the two
that replace the old required Firestore composite indexes.

### Row Level Security

Read-open to authenticated users, writes locked to the owner. Friendships are
visible only to the two participants; only the receiver can accept/decline.
Notifications are readable only by the recipient, and you may only insert one
where you are the actor. Avatars must be uploaded to `avatars/<uid>/...`.

### Auth deep links

Confirmation / reset emails redirect to `cinemon://login-callback`, registered
in iOS `CFBundleURLSchemes` and the Android intent filter, and allowlisted
under Supabase URL Configuration. Without it, Supabase falls back to the Site
URL (`http://localhost:3000`), which cannot open on a phone.

---

## Phase 3: User Profiles & Social Features

### Priority 1: User Profile Setup - COMPLETE

~~Currently, `username` and `userPhotoUrl` are not being set during signup. This is why posts show "Unknown" as the username and a placeholder avatar.~~

**Completed Tasks:**
1. **Profile Setup Flow** (after signup) - DONE
   - Username input with real-time availability check (debounced 500ms)
   - Profile photo upload (Supabase Storage, `avatars` bucket)
   - Optional bio field (150 char limit)
   - Save to the `profiles` table
   - Router redirects new users to `/profile-setup`

2. **Edit Profile Screen** - DONE
   - Change username (with availability check)
   - Change profile photo
   - Update bio
   - Route: `/edit-profile`

3. **Profile Page Enhancement** - DONE
   - Display user's posts in grid
   - Show follower/following/review counts
   - Edit profile button for own profile
   - Settings menu with sign out
   - Activity grid showing watched/reviewed films

4. **Follow/Unfollow System** - DONE
   - Follow/unfollow button on other profiles
   - Handles: Follow, Requested, Accept/Decline, Following states
   - Unfollow confirmation dialog
   - Updates follower/following counts

5. **User Search & Discovery** - DONE
   - Search users by username (debounced)
   - User list with profile photos
   - Navigate to user profiles from search
   - Route: `/search-users`

6. **View Other Profiles** - DONE
   - Route: `/profile/:userId`
   - Shows other user's posts and stats
   - Follow button instead of Edit Profile

### Priority 2: Social Features - MOSTLY COMPLETE

1. **Friend/Follow System** - DONE
   - Search users by username
   - Send follow request
   - Accept/decline requests
   - Unfollow functionality
   - ~~Pending requests badge/notification~~ (TODO)

2. **Activity Interactions**
   - Like/unlike posts (already has data model)
   - Comment on posts
   - Share functionality (optional)

3. **User Discovery**
   - Search users
   - Suggested users to follow
   - View other user profiles

### Priority 3: Enhanced Film Features

1. **Film Detail Page**
   - Show TMDB details (synopsis, cast, etc.)
   - Display all reviews from friends
   - Average rating from friends
   - "I've watched this" quick action

2. **Watchlist**
   - Add films to watchlist
   - View/manage watchlist
   - Mark as watched from watchlist

3. **Film Search Improvements**
   - Filter by movie/TV
   - Browse by genre
   - Popular/top rated sections

---

## Technical Debt & Improvements

### Known Issues
- [x] Profile photo and username not set during signup (FIXED - Profile setup screen added)
- [x] Denormalized user data won't update on profile edit (FIXED - `feed_activities`
      joins profiles live, so there is nothing to denormalize)
- [x] No pagination on home feed (FIXED - keyset pagination via `before:` cursor)
- [ ] Stream providers not fully utilized (using FutureProvider with refresh)

### Suggested Improvements
- [ ] Add proper error toasts/snackbars instead of inline errors
- [ ] Implement infinite scroll pagination
- [ ] Add offline support with local caching
- [ ] Optimize image loading with proper caching strategy
- [ ] Add unit tests for repositories and providers
- [ ] Add integration tests for critical flows

### Code Quality
- [ ] Run `flutter analyze` and fix warnings
- [ ] Add proper logging instead of print statements
- [ ] Consider adding a proper DI setup (get_it or similar)
- [ ] Add environment configuration for API keys

---

## Quick Start for Next Session

1. **Run build_runner** (if models changed):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. **Start the app**:
   ```bash
   flutter run -d burritoman            # debug, hot reload
   flutter run -d burritoman --release  # instant launch, no debugger
   ```

   **Quit Xcode first.** It competes with `flutter run` for the device.
   If the app launches to a white screen, orphaned launchers are holding it
   suspended at entry (`--start-stopped`) — check and clear them:
   ```bash
   pgrep -fl "devicectl device process launch"   # then kill -9 <pid>
   ```

3. **Flutter SDK** lives at `~/development/flutter`, pinned to 3.38.6.
   `flutter upgrade` needs `git checkout stable` in that dir first — don't
   upgrade right before a TestFlight build.

3. **Key files to review**:
   - `lib/providers/user/user_provider.dart` - User profile & setup state
   - `lib/screens/auth/profile_setup_screen.dart` - Profile setup UI
   - `lib/core/routes/app_router.dart` - Routing with profile check
   - `lib/repositories/user_repository.dart` - User operations

4. **Phase 3 Status**: User profiles & social features mostly complete!

   **Remaining tasks**:
   - Pending friend requests badge/notification
   - Like/unlike posts
   - Comment on posts
   - Film detail page with friends' reviews

---

## Dependencies

Key packages used:
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `freezed` / `json_serializable` - Immutable models
- `supabase_flutter` - auth, Postgres, storage, realtime
- `dio` - HTTP client for TMDB
- `cached_network_image` - Image caching
- `shimmer` - Loading placeholders
- `flutter_animate` - Animations

TMDB API Key: Configured in `lib/core/constants/api_constants.dart`

Supabase URL + publishable key: `lib/core/config/supabase_config.dart`,
overridable at build time with `--dart-define=SUPABASE_URL=... SUPABASE_KEY=...`.
The publishable key is safe to commit; RLS is what protects the data. Never
put the service-role/secret key in the client.

### Building for TestFlight

```bash
./scripts_build_ipa.sh          # bump pubspec `version:` FIRST
```

Shipped builds so far: 1.0.0 (1), 1.0.0 (2) — Jan 18 2026; 1.0.1 (3) — Aug 2026.

**The rsync trap:** `flutter build ipa` fails with the unhelpful
`error: exportArchive Copy failed` because Xcode's export shells out to rsync
and MacPorts' rsync 3.2.7 (`/opt/local/bin`) shadows Apple's openrsync. The
script retries the export with `PATH=/usr/bin:...` which fixes it. The real
error is only visible in the distribution logs:
`rsync error: syntax or usage error (code 1)` in
`/var/folders/.../Runner_*.xcdistributionlogs/IDEDistribution.standard.log`.

### Before shipping to real TestFlight testers
- Re-enable "Confirm email" (Authentication -> Sign In / Providers -> Email)
- Set up custom SMTP — the built-in sender is rate-limited and not for production
- Bump `version:` in pubspec.yaml; App Store Connect rejects reused build numbers
