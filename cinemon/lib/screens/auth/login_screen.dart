import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart';
import '../../providers/friendship/friendship_provider.dart';

/// Login screen with dark cinematic aesthetic
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAnimating = false;

  late AnimationController _fieldsController;
  late AnimationController _logoController;
  late Animation<double> _fieldsOpacity;
  late Animation<double> _fieldsScale;
  late Animation<Offset> _logoPosition;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    // Fields collapse animation
    _fieldsController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fieldsOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fieldsController, curve: Curves.easeInCubic),
    );

    _fieldsScale = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _fieldsController, curve: Curves.easeInCubic),
    );

    // Logo center and expand animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _logoPosition = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.2),
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOutCubic),
      ),
    );

    _logoScale = Tween<double>(begin: 1.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _logoFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInCubic),
      ),
    );

    // Navigate after animation completes
    _logoController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fieldsController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Check for errors
      final authState = ref.read(authControllerProvider);
      if (authState.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      } else if (!authState.isLoading && mounted) {
        // Success! Clear any cached data from previous user
        ref.invalidate(currentUserProfileProvider);
        ref.invalidate(homeFeedProvider);
        ref.invalidate(friendIdsProvider);

        // Trigger animations
        setState(() => _isAnimating = true);
        await _fieldsController.forward();
        await _logoController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color.fromARGB(255, 3, 1, 32),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  // App Logo - positioned to overlay the light leak
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_fieldsController, _logoController]),
                    builder: (context, child) {
                      return SlideTransition(
                        position: _logoPosition,
                        child: Opacity(
                          opacity: _logoFade.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Image.asset(
                              'assets/images/35mm_final_logo.png',
                              width: MediaQuery.of(context).size.width * 0.90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Email Field
                  AnimatedBuilder(
                    animation: _fieldsController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fieldsOpacity.value,
                        child: Transform.scale(
                          scale: _fieldsScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: SizedBox(
                        width: 320,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: const TextStyle(
                              color: Colors.white,
                            ),
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: Color.fromARGB(255, 255, 255, 255),
                                size: 20),
                            filled: false,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  AnimatedBuilder(
                    animation: _fieldsController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fieldsOpacity.value,
                        child: Transform.scale(
                          scale: _fieldsScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: SizedBox(
                        width: 320,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                            prefixIcon: const Icon(Icons.password_outlined,
                                color: Color.fromARGB(255, 255, 255, 255),
                                size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color.fromARGB(255, 255, 255, 255),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: false,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Button
                  AnimatedBuilder(
                    animation: _fieldsController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fieldsOpacity.value,
                        child: Transform.scale(
                          scale: _fieldsScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: SizedBox(
                        width: 150,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            elevation: 0,
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Forgot Password
                  AnimatedBuilder(
                    animation: _fieldsController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fieldsOpacity.value,
                        child: Transform.scale(
                          scale: _fieldsScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: Navigate to forgot password screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset coming soon!'),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color.fromARGB(255, 200, 199, 199),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Sign Up Link
                  AnimatedBuilder(
                    animation: _fieldsController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fieldsOpacity.value,
                        child: Transform.scale(
                          scale: _fieldsScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                                color: Color.fromARGB(255, 201, 200, 200)),
                          ),
                          TextButton(
                            onPressed: () {
                              context.go('/signup');
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
