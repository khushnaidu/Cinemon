import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'widgets/app_search_field.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../providers/feed/feed_provider.dart';
import '../providers/auth/auth_provider.dart';

/// Provider for user search results
final userSearchProvider = FutureProvider.family<List<UserModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final userRepo = ref.read(userRepositoryProvider);
  return userRepo.searchUsers(query.trim());
});

/// Screen for searching and discovering users
class SearchUsersScreen extends ConsumerStatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  ConsumerState<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends ConsumerState<SearchUsersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = value.trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              AppColors.canvas,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and search
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, color: AppColors.ink),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppSearchField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        placeholder: 'Search users',
                        autofocus: true,
                      ),
                    ),
                  ],
                ),
              ),

              // Search Results
              Expanded(
                child: _searchQuery.isEmpty
                    ? _buildEmptyState()
                    : _buildSearchResults(currentUser?.uid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Find friends',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by username to find people',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(String? currentUserId) {
    final searchResults = ref.watch(userSearchProvider(_searchQuery));

    return searchResults.when(
      data: (users) {
        // Filter out current user from results
        final filteredUsers = users.where((u) => u.uid != currentUserId).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userSearchProvider(_searchQuery));
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.white,
          backgroundColor: AppColors.surface,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return _UserListTile(user: user);
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error searching users',
              style: TextStyle(color: Colors.red[300]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(userSearchProvider(_searchQuery)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual user list tile
class _UserListTile extends StatelessWidget {
  final UserModel user;

  const _UserListTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/profile/${user.uid}'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white24,
        backgroundImage: user.photoUrl != null
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? const Icon(Icons.person, color: Colors.white54, size: 28)
            : null,
      ),
      title: Text(
        '@${user.username}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: user.bio != null && user.bio!.isNotEmpty
          ? Text(
              user.bio!,
              style: const TextStyle(color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              '${user.reviewCount} reviews',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
      ),
    );
  }
}
