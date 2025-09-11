import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/services/local_storage_service.dart';
import 'auth/welcome_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'home/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final localStorage = LocalStorageService();

      // Check if first time user
      final isFirstTime = localStorage.isFirstTimeUser();

      if (isFirstTime) {
        // Show welcome screen for first-time users
        await localStorage.setFirstTimeUser(false);
        _navigateToWelcome();
      } else if (authProvider.isAuthenticated) {
        // User is logged in, go to main screen
        _navigateToMain();
      } else {
        // User is not logged in, go to welcome screen
        _navigateToWelcome();
      }
    }
  }

  void _navigateToWelcome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
      ),
    );
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.podcasts_rounded,
                        size: 60,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // App Title
                    const Text(
                      'Podcast Tracker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // App Tagline
                    Text(
                      'Discover, Listen, Track',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 50),

                    // Loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}