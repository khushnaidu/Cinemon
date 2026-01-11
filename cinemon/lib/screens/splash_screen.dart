import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Splash screen with animated logo GIF and smooth transitions
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _fadeOut = false;

  @override
  void initState() {
    super.initState();
    _startTransitionTimer();
  }

  void _startTransitionTimer() {
    // Let the GIF play, then fade out and navigate
    // Adjust this duration to match your GIF length
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() => _fadeOut = true);
      }
    });

    // Navigate after fade out completes
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _fadeOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Center(
          child: Image.asset(
            'assets/images/background.gif',
            width: MediaQuery.of(context).size.width * 0.85,
            fit: BoxFit.contain,
          )
              .animate()
              .fadeIn(
                duration: 400.ms,
                curve: Curves.easeOut,
              )
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
                curve: Curves.easeOut,
              ),
        ),
      ),
    );
  }
}
