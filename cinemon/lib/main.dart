import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemon/core/config/supabase_config.dart';
import 'package:cinemon/core/routes/app_router.dart';
import 'package:cinemon/core/theme/app_theme.dart';
import 'package:cinemon/screens/profile/about_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait everywhere. Trailers' landscape turns its own view instead of
  // the phone (trailers_screen.dart).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  registerFontLicences();

  await SupabaseConfig.initialize();

  // Run app wrapped with Riverpod's ProviderScope
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.dark,
    );
  }
}
