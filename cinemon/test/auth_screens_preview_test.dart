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
import 'package:cinemon/repositories/auth_repository.dart';
import 'package:cinemon/repositories/user_repository.dart';
import 'package:cinemon/screens/auth/login_screen.dart';
import 'package:cinemon/screens/auth/onboarding_screen.dart';
import 'package:cinemon/screens/auth/password_reset_screens.dart';
import 'package:cinemon/screens/auth/signup_screen.dart';
import 'package:cinemon/screens/auth/verify_code_screen.dart';
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

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'signup': () => const SignupScreen(),
    'verify': () => const VerifyCodeScreen(
        email: 'carol.king@example.com', purpose: CodePurpose.signup),
    'forgot': () => const ForgotPasswordScreen(),
    'new_password': () => const NewPasswordScreen(),
    'onboarding': () => const OnboardingScreen(),
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
