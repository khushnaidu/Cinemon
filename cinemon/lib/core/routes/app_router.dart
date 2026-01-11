import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/profile_setup_screen.dart';
import '../../screens/homefeed.dart';
import '../../screens/post.dart' show MovieSearchPage;
import '../../screens/create_post_screen.dart';
import '../../screens/profile.dart';
import '../../screens/edit_profile_screen.dart';
import '../../screens/search_users_screen.dart';
import '../../screens/friends_list_screen.dart';
import '../../screens/film_detail_screen.dart';
import '../../screens/profile/user_activity_screen.dart';
import '../../models/activity_model.dart';

/// GoRouter configuration with auth guard
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final location = state.matchedLocation;

      // Allow splash screen to always show
      if (location == '/') {
        return null;
      }

      // Check if user is loading
      final isLoading = authState.isLoading;
      if (isLoading) {
        return null; // Wait for auth to load
      }

      // Check if user is authenticated
      final user = authState.value;
      final isAuthenticated = user != null;

      // Define page categories
      final isOnAuthPage = location == '/login' || location == '/signup';

      // Redirect logic for unauthenticated users
      if (!isAuthenticated) {
        if (isOnAuthPage) {
          return null; // Stay on auth page
        }
        return '/login'; // Redirect to login
      }

      // User is authenticated
      if (isAuthenticated) {
        // If on auth pages, redirect to home
        if (isOnAuthPage) {
          return '/home';
        }

        // Profile setup is now optional - users can skip it
        // No automatic redirect to profile-setup
      }

      // No redirect needed
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
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeFeedPage(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const MovieSearchPage(),
      ),
      GoRoute(
        path: '/create',
        name: 'create',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
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
      GoRoute(
        path: '/friends',
        name: 'friends',
        builder: (context, state) => const FriendsListScreen(),
      ),
      GoRoute(
        path: '/search-users',
        name: 'search-users',
        builder: (context, state) => const SearchUsersScreen(),
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
                child: Text('Invalid film ID', style: TextStyle(color: Colors.white)),
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
