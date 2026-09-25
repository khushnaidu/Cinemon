// Renders the auth screens (ADR 0004 D8) to PNG with the Mac's system fonts,
// to check layout without a phone. Skipped unless AUTH_PREVIEW_OUT is set:
//
//   AUTH_PREVIEW_OUT=/tmp/auth flutter test test/auth_screens_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cinemon/core/theme/app_theme.dart';
import 'package:cinemon/models/user_model.dart';
import 'package:cinemon/providers/auth/auth_provider.dart';
import 'package:cinemon/providers/feed/feed_provider.dart';
import 'package:cinemon/providers/follow/follow_provider.dart';
import 'package:cinemon/repositories/auth_repository.dart';
import 'package:cinemon/repositories/user_repository.dart';
import 'package:cinemon/screens/auth/login_screen.dart';
import 'package:cinemon/screens/auth/onboarding_screen.dart';
import 'package:cinemon/screens/auth/password_reset_screens.dart';
import 'package:cinemon/screens/auth/signup_screen.dart';
import 'package:cinemon/screens/auth/verify_code_screen.dart';
import 'package:cinemon/models/notification_model.dart';
import 'package:cinemon/providers/notification/notification_provider.dart';
import 'package:cinemon/screens/notifications_screen.dart';
import 'package:cinemon/screens/search_users_screen.dart';
import 'package:cinemon/providers/auth/onboarding_provider.dart';
import 'package:cinemon/screens/auth/agree_screen.dart';
import 'package:cinemon/screens/help_screen.dart';
import 'package:cinemon/screens/shell/first_run_tour.dart';
import 'package:cinemon/screens/profile/profile_header.dart';
import 'package:cinemon/screens/widgets/arch_profile_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, User;

final _out = Platform.environment['AUTH_PREVIEW_OUT'];

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}

class _FreeNames extends UserRepository {
  _FreeNames(SupabaseClient client) : super(client: client);

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      username != 'taken';
}

void main() {
  final skip = _out == null;

  setUpAll(() async {
    if (skip) return;
    const sf = '/System/Library/Fonts/SFNS.ttf';
    await _font('CupertinoSystemText', [sf]);
    await _font('CupertinoSystemDisplay', [sf]);
    await _font('Roboto', [sf]);
    await _font('Helvetica Neue', ['/System/Library/Fonts/HelveticaNeue.ttc']);
    // USERNAME_FONT_FILE renders another candidate in the username slot.
    await _font(AppText.usernameFamily, [
      Platform.environment['USERNAME_FONT_FILE'] ??
          'assets/fonts/username/Brafesuit.ttf',
    ]);
    final home = Platform.environment['HOME'];
    await _font('packages/cupertino_icons/CupertinoIcons', [
      '$home/.pub-cache/hosted/pub.dev/cupertino_icons-1.0.6/assets/CupertinoIcons.ttf'
    ]);
  });

  final client = SupabaseClient('http://localhost:1', 'preview');
  final user = User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'carol.king@example.com',
    createdAt: '2026-09-24T00:00:00Z',
  );
  final profile = UserModel(
    uid: 'u1',
    username: 'user_abc1234567',
    displayName: 'Carol King',
    createdAt: DateTime(2026, 9, 24),
  );

  final now = DateTime.now();
  NotificationModel note(String id, NotificationType type, String actor,
          Duration ago,
          {String? poster, String? preview, int? vote, bool read = true}) =>
      NotificationModel(
        id: id,
        recipientId: 'u1',
        actorId: actor,
        actorUsername: actor,
        type: type,
        filmTitle: poster == null ? null : 'Past Lives',
        filmPosterPath: poster,
        commentPreview: preview,
        vote: vote,
        isRead: read,
        createdAt: now.subtract(ago),
      );
  final notes = [
    note('1', NotificationType.followRequest, 'asker', const Duration(minutes: 3),
        read: false),
    note('2', NotificationType.follow, 'fan', const Duration(hours: 1),
        read: false),
    note('3', NotificationType.follow, 'pal', const Duration(hours: 5)),
    note('4', NotificationType.like, 'pal', const Duration(hours: 7),
        poster: '/x.jpg'),
    note('5', NotificationType.vote, 'fan', const Duration(days: 2),
        vote: -1, preview: 'Nolan peaked with The Prestige'),
    note('6', NotificationType.exploreComment, 'dave',
        const Duration(days: 3),
        poster: '/x.jpg', preview: 'hard agree, the last scene wrecked me'),
    note('7', NotificationType.listSave, 'bob', const Duration(days: 12)),
    note('8', NotificationType.followAccepted, 'stranger',
        const Duration(days: 20)),
  ];

  final screens = <String, Widget Function()>{
    'activity': () => const NotificationsScreen(),
    'agree': () => const AgreeScreen(),
    'help': () => const HelpScreen(),
    'tour_welcome': () => Scaffold(
        backgroundColor: const Color(0xFF223344),
        body: FirstRunTour(onDone: () {})),
    'tour_post': () => Scaffold(
        backgroundColor: const Color(0xFF223344),
        body: FirstRunTour(onDone: () {})),
    'tour_people': () => Scaffold(
        backgroundColor: const Color(0xFF223344),
        body: FirstRunTour(onDone: () {})),
    'find_people': () => const SearchUsersScreen(),
    'login': () => const LoginScreen(),
    'signup': () => const SignupScreen(),
    'verify': () => const VerifyCodeScreen(
        email: 'carol.king@example.com', purpose: CodePurpose.signup),
    'forgot': () => const ForgotPasswordScreen(),
    'new_password': () => const NewPasswordScreen(),
    'onboarding': () => const OnboardingScreen(),
    // Someone who follows you and has asked to (a private account's view).
    'profile_other_request': () => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: ProfileHeader(
              profile: profile.copyWith(uid: 'asker', username: 'carol'),
              isOwnProfile: false,
            ),
          ),
        ),
    // You follow each other.
    'profile_other_friends': () => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: ProfileHeader(
              profile: profile.copyWith(uid: 'pal', username: 'dave'),
              isOwnProfile: false,
            ),
          ),
        ),
    // Someone who follows you, whom you don't follow yet.
    'profile_other_followback': () => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: ProfileHeader(
              profile: profile.copyWith(uid: 'fan', username: 'bob'),
              isOwnProfile: false,
            ),
          ),
        ),
    // The top of your own profile: brush name, grey @name, then the rest.
    'profile_header': () => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: ProfileHeader(
              profile: profile.copyWith(
                username: 'khush',
                bio: 'films, feelings, and far too many opinions',
              ),
              isOwnProfile: true,
            ),
          ),
        ),
    // Usernames under the profile photo: a short one, and the longest kind.
    'username_arch': () => const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ArchProfileFrame(
                    photoUrl: null,
                    username: 'lilkhush',
                    width: 120,
                    height: 160),
                SizedBox(height: 80),
                ArchProfileFrame(
                    photoUrl: null,
                    username: 'user_4f2a9c01b7.films_2024',
                    width: 120,
                    height: 160),
              ],
            ),
          ),
        ),
  };

  for (final entry in screens.entries) {
    testWidgets('render ${entry.key}', skip: skip, (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider
              .overrideWithValue(AuthRepository(client: client)),
          userRepositoryProvider.overrideWithValue(_FreeNames(client)),
          currentUserProvider.overrideWithValue(user),
          currentUserProfileProvider.overrideWith((ref) async => profile),
          termsStatusProvider.overrideWith((ref) async =>
              const TermsStatus(accepted: false, ageKnown: false)),
          notificationsStreamProvider
              .overrideWith((ref) => Stream.value(notes)),
          followRequestCountProvider.overrideWith((ref) => Stream.value(1)),
          userSearchProvider.overrideWith((ref, q) async => [
                profile.copyWith(uid: 'pal', username: 'dave', displayName: 'Dave Ruiz'),
                profile.copyWith(uid: 'fan', username: 'bob', displayName: 'Bob'),
                profile.copyWith(uid: 'stranger', username: 'daria', displayName: 'Daria M'),
              ]),
          isPrivateProvider.overrideWith((ref, id) async => false),
          followRelationProvider.overrideWith((ref, id) async => id == 'pal'
              ? const FollowRelation(
                  outgoing: FollowState.following,
                  incoming: FollowState.following)
              : id == 'asker'
                  ? const FollowRelation(
                      outgoing: FollowState.none,
                      incoming: FollowState.requested)
                  : const FollowRelation(
                      outgoing: FollowState.none,
                      incoming: FollowState.following)),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: entry.value(),
          ),
        ),
      ));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/images/35mm_final_logo.png'),
          tester.element(find.byKey(key))));
      if (entry.key == 'tour_post' || entry.key == 'tour_people') {
        await tester.tap(find.text('Show me'));
        await tester.pump();
        if (entry.key == 'tour_people') {
          await tester.tap(find.text('Next'));
          await tester.pump();
        }
      }
      if (entry.key == 'find_people') {
        await tester.enterText(find.byType(EditableText), 'da');
        await tester.pump(const Duration(milliseconds: 500));
      }
      // Let the onboarding prefill and its availability check land.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out!).createSync(recursive: true);
        File('$_out/${entry.key}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
