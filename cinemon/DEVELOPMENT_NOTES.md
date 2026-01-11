# Cinemon Development Notes

## Current Status: Phase 3 In Progress (Profile Setup Complete)

### What's Been Built

#### Phase 1: Core Setup & Authentication
- Firebase integration (Auth, Firestore)
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
  - `FeedRepository` - Firestore CRUD for activities
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
  - Profile photo picker with Firebase Storage upload
  - Optional bio field (150 char limit)
  - Visual feedback for username validation (green check/red X)

- **User Provider** (`lib/providers/user/user_provider.dart`)
  - `userRepositoryProvider` - UserRepository instance
  - `firebaseStorageProvider` - Firebase Storage instance
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

### Firestore Structure

```
users/
  {userId}/
    - uid: string
    - email: string
    - username: string (NEEDS SETUP)
    - photoUrl: string? (NEEDS SETUP)
    - bio: string?
    - reviewCount: int
    - createdAt: timestamp

activities/
  {activityId}/
    - userId: string
    - username: string (denormalized)
    - userPhotoUrl: string? (denormalized)
    - activityType: "watched" | "reviewed"
    - filmId: int (TMDB ID)
    - filmTitle: string
    - filmPosterPath: string?
    - filmYear: string?
    - mediaType: "movie" | "tv"
    - rating: double? (1-5)
    - reviewText: string?
    - createdAt: timestamp
    - likes: string[] (user IDs)
    - commentCount: int

    comments/ (subcollection)
      {commentId}/
        - userId, username, content, createdAt

friendships/
  {friendshipId}/
    - user1Id, user2Id
    - status: "pending" | "accepted" | "declined"
    - createdAt
```

### Required Firestore Indexes

Create these composite indexes in Firebase Console:

1. **Activities Feed Query**
   - Collection: `activities`
   - Fields: `userId` (Arrays), `createdAt` (Descending)

2. **User Activities Query**
   - Collection: `activities`
   - Fields: `userId` (Ascending), `createdAt` (Descending)

---

## Phase 3: User Profiles & Social Features

### Priority 1: User Profile Setup - COMPLETE

~~Currently, `username` and `userPhotoUrl` are not being set during signup. This is why posts show "Unknown" as the username and a placeholder avatar.~~

**Completed Tasks:**
1. **Profile Setup Flow** (after signup) - DONE
   - Username input with real-time availability check (debounced 500ms)
   - Profile photo upload (Firebase Storage)
   - Optional bio field (150 char limit)
   - Save to Firestore `users` collection
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
- [ ] Denormalized user data (username, photoUrl) won't update if user changes profile
- [ ] No pagination on home feed (currently limited to 20)
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
   flutter run
   ```

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
- `firebase_core`, `firebase_auth`, `cloud_firestore` - Firebase
- `dio` - HTTP client for TMDB
- `cached_network_image` - Image caching
- `shimmer` - Loading placeholders
- `flutter_animate` - Animations

TMDB API Key: Configured in `lib/core/constants/api_constants.dart`
