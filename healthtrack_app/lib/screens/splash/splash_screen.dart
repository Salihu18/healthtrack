import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/weight_provider.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve:  Curves.easeIn,
    );

    _slideAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve:  Curves.easeOut,
      ),
    );

    _controller.forward();

    // After 2.5 seconds decide where to navigate
    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in — load their data then go to dashboard
      await context.read<UserProvider>().loadUser(user.uid);
      if (!mounted) return;
      context.read<FoodProvider>().listenToToday(user.uid);
      context.read<WeightProvider>().loadHistory(user.uid);
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      // Not logged in — go to login
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnim.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: child,
              ),
            );
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Logo icon ──────────────────────────────
                Container(
                  width:  100,
                  height: 100,
                  decoration: BoxDecoration(
                    color:        AppColors.primary.withValues(alpha: 0.12),
                    shape:        BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.primary,
                      size:  48,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Brand name ─────────────────────────────
                const Text(
                  'HealthTrack',
                  style: TextStyle(
                    color:       AppColors.textPrimary,
                    fontSize:    36,
                    fontWeight:  FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Tagline ────────────────────────────────
                const Text(
                  'Your health, your journey',
                  style: TextStyle(
                    color:        AppColors.textSecondary,
                    fontSize:     14,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 64),

                // ── Loading indicator ──────────────────────
                const SizedBox(
                  width:  24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color:       AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}