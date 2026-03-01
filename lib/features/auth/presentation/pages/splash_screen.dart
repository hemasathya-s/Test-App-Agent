import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for splash animation/delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      print('🔎 Splash check - Access Token: $accessToken');

      if (accessToken != null && accessToken.isNotEmpty) {
        print('✅ Token found, navigating to Home');
        context.go('/home');
      } else {
        print('❌ No token found, navigating to Login');
        context.go('/login');
      }
    } catch (e) {
      print('⚠️ Error checking auth: $e');
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 60,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'UC Agent',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Empowering Professionals',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
