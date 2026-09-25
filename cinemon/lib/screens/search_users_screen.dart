import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/feed/feed_provider.dart';
import 'follow_list_screen.dart' show PersonFollowButton, PersonRow;
import 'widgets/app_search_field.dart';
import 'widgets/comments_sheet.dart' show GlassHint;

/// Provider for user search results
final userSearchProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final userRepo = ref.read(userRepositoryProvider);
  return userRepo.searchUsers(query.trim());
});

/// Find people by username. Laid out like Followers and Following, with the
/// follow button on each row.
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
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xs, AppSpace.xs, AppSpace.lg, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(CupertinoIcons.chevron_back,
                        color: AppColors.ink),
                    tooltip: 'Back',
                  ),
                  const Expanded(
                    child: Text('Find people', style: AppText.title),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                placeholder: 'Search by username',
                autofocus: true,
              ),
            ),
            Expanded(
              child: _searchQuery.isEmpty
                  ? const GlassHint(
                      icon: CupertinoIcons.person_crop_circle_badge_plus,
                      title: 'Find people',
                      body: 'Search by username to find people you know.',
                    )
                  : _buildSearchResults(me),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(String? me) {
    final searchResults = ref.watch(userSearchProvider(_searchQuery));

    return searchResults.when(
      loading: () => const Center(
        child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
      ),
      error: (_, __) => const GlassHint(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: 'Couldn\'t search',
        body: 'Check your connection and try again.',
      ),
      data: (users) {
        final found = users.where((u) => u.uid != me).toList();
        if (found.isEmpty) {
          return const GlassHint(
            icon: CupertinoIcons.search,
            title: 'No one matches',
            body: 'Try a different username.',
          );
        }
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg,
              MediaQuery.paddingOf(context).bottom + AppSpace.lg),
          itemCount: found.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xs),
          itemBuilder: (_, i) => PersonRow(
            user: found[i],
            trailing: PersonFollowButton(
              userId: found[i].uid,
              username: found[i].username,
            ),
          ),
        );
      },
    );
  }
}
