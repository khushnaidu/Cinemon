import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../providers/auth/onboarding_provider.dart';
import '../../screens/auth/agree_screen.dart';
import '../../screens/help_screen.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/auth/password_reset_screens.dart';
import '../../screens/auth/verify_code_screen.dart';
import 'redirect_hold.dart';
import '../../screens/homefeed.dart';
import '../../screens/shell/glass_shell.dart';
import '../../screens/post.dart' show MovieSearchPage;
import '../../screens/explore/explore_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/edit_profile_screen.dart';
import '../../screens/search_users_screen.dart';
import '../../providers/follow/follow_provider.dart' show FollowListKind;
import '../../screens/follow_list_screen.dart';
import '../../screens/film_detail_screen.dart';
import '../../screens/profile/user_activity_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../models/activity_model.dart';
import '../../screens/lists/playlist_screen.dart';
import '../../screens/person/person_screen.dart';
import '../../screens/trailers/trailers_screen.dart';
import '../../share/shared_link_screens.dart';

/// Pings the router to re-run its redirect.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Screens you can be on signed out.
const _signedOutPages = {'/login', '/signup', '/verify', '/forgot'};

/// One router for the life of the app. Signing in or out, finishing
/// onboarding and the login screen's hold re-run [redirect] rather than
/// rebuilding the router, which used to replay the splash on every login.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authStateProvider, (_, __) => refresh.ping());
  ref.listen(onboardedProvider, (_, __) => refresh.ping());
  ref.listen(termsStatusProvider, (_, __) => refresh.ping());
  authRedirectHold.addListener(refresh.ping);
  ref.onDispose(() {
    authRedirectHold.removeListener(refresh.ping);
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    // Lets the glass shell unmount its platform view whenever a route or a
    // modal sheet covers it — see shellRouteObserver.
    observers: [shellRouteObserver],
    redirect: (context, state) {
      final location = state.matchedLocation;

      // The splash moves itself on; the login screen holds while its logo
      // zoom plays.
      if (location == '/' || authRedirectHold.value) return null;

      final auth = ref.read(authStateProvider);
      if (auth.isLoading && !auth.hasValue) return null;

      final user = auth.valueOrNull;
      if (user == null) {
        return _signedOutPages.contains(location) ? null : '/login';
      }

      // A reset code signs you in; finish by choosing the password.
      if (location == '/new-password') return null;
      if (location == '/verify' &&
          state.uri.queryParameters['purpose'] == 'recovery') {
        return '/new-password';
      }

      // The current Terms, and an age, before anything else (migration 021).
      final terms = ref.read(termsStatusProvider);
      if (terms.isLoading && !terms.hasValue) return null;
      final status = terms.valueOrNull;
      if (status != null && !status.accepted) {
        return location == '/agree' ? null : '/agree';
      }
      if (location == '/agree') return '/home';

      // Everyone new picks a username first (ADR 0004 D7). If the lookup
      // fails, let them in: everyone from before onboarding counts as done.
      final onboarded = ref.read(onboardedProvider);
      if (onboarded.isLoading && !onboarded.hasValue) {
        return null;
      }
      if (onboarded.valueOrNull == false) {
        return location == '/onboarding' ? null : '/onboarding';
      }
      if (_signedOutPages.contains(location) || location == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => VerifyCodeScreen(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: state.uri.queryParameters['purpose'] == 'recovery'
              ? CodePurpose.recovery
              : CodePurpose.signup,
        ),
      ),
      GoRoute(
        path: '/forgot',
        builder: (context, state) =>
            ForgotPasswordScreen(email: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: '/new-password',
        builder: (context, state) => const NewPasswordScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: '/agree',
        builder: (context, state) => const AgreeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // The five tabs live in a shell so the glass bar persists across
      // switches and each branch keeps its own stack and scroll position.
      //
      // Every branch carries branchDepthObserver: modal sheets open on the
      // branch's own navigator, not the root, so this is the only place the
      // shell can hear about them.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            GlassShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(observers: [
            branchDepthObserver()
          ], routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeFeedPage(),
            ),
          ]),
          StatefulShellBranch(observers: [
            branchDepthObserver()
          ], routes: [
            GoRoute(
              path: '/search',
              name: 'search',
              builder: (context, state) => const MovieSearchPage(),
            ),
          ]),
          StatefulShellBranch(observers: [
            branchDepthObserver()
          ], routes: [
            GoRoute(
              path: '/explore',
              name: 'explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ]),
          StatefulShellBranch(observers: [
            branchDepthObserver()
          ], routes: [
            GoRoute(
              path: '/trailers',
              name: 'trailers',
              builder: (context, state) => const TrailersScreen(),
            ),
          ]),
          StatefulShellBranch(observers: [
            branchDepthObserver()
          ], routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/profile/:userId',
        name: 'user-profile',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return ProfilePage(userId: userId);
        },
      ),
      GoRoute(
        path: '/activity/:userId',
        name: 'user-activity',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final username = state.extra as String?;
          return UserActivityScreen(
            userId: userId,
            username: username,
          );
        },
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      // Your people: requests, followers, following.
      GoRoute(
        path: '/friends',
        name: 'friends',
        builder: (context, state) => const FollowListScreen(),
      ),
      // Anyone's followers or following: /follows/<id>?tab=followers
      GoRoute(
        path: '/follows/:userId',
        builder: (context, state) => FollowListScreen(
          userId: state.pathParameters['userId'],
          initial: state.uri.queryParameters['tab'] == 'followers'
              ? FollowListKind.followers
              : FollowListKind.following,
        ),
      ),
      GoRoute(
        path: '/search-users',
        name: 'search-users',
        builder: (context, state) => const SearchUsersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/lists/:listId',
        name: 'list',
        builder: (context, state) =>
            ListScreen(listId: state.pathParameters['listId']!),
      ),
      // Share links: https://35mm.contact/l/<id> arrives here as a universal
      // link (Flutter hands the path to the router).
      GoRoute(
        path: '/l/:listId',
        redirect: (context, state) =>
            '/lists/${state.pathParameters['listId']}',
      ),
      // Story link stickers (ADR 0003): a post, or someone's profile.
      GoRoute(
        path: '/p/:postId',
        builder: (context, state) =>
            SharedPostScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/u/:username',
        builder: (context, state) =>
            SharedProfileScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/person/:personId',
        name: 'person',
        builder: (context, state) {
          final personId = int.tryParse(state.pathParameters['personId'] ?? '');
          if (personId == null) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text('Person not found',
                    style: TextStyle(color: Colors.white)),
              ),
            );
          }
          return PersonScreen(personId: personId);
        },
      ),
      GoRoute(
        path: '/film/:filmId/:mediaType',
        name: 'film-detail',
        builder: (context, state) {
          final filmIdStr = state.pathParameters['filmId'];
          final mediaType = state.pathParameters['mediaType'] ?? 'movie';

          // Safely parse filmId
          final filmId = int.tryParse(filmIdStr ?? '');
          if (filmId == null) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: const Center(
                child: Text('Invalid film ID',
                    style: TextStyle(color: Colors.white)),
              ),
            );
          }

          // Optional: pass activity via extra
          final activity = state.extra as ActivityModel?;
          return FilmDetailScreen(
            filmId: filmId,
            mediaType: mediaType,
            existingActivity: activity,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
