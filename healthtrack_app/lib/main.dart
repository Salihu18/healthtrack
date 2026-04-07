import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'providers/user_provider.dart';
import 'providers/food_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'providers/weight_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline caching — app works without internet
  FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
);

  runApp(const HealthTrackApp());
}

class HealthTrackApp extends StatelessWidget {
  const HealthTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FoodProvider()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
      ],
      child: MaterialApp(
        title:                    'HealthTrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
  brightness:              Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorSchemeSeed:         AppColors.primary,
  useMaterial3:            true,
  textTheme: GoogleFonts.nunitoTextTheme(
    ThemeData.dark().textTheme,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surface,
    elevation:       0,
    centerTitle:     false,
  ),
  cardTheme: CardThemeData(       // ← CardThemeData not CardTheme
    color:     AppColors.card,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled:      true,
    fillColor:   AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:   BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:   BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle:  const TextStyle(color: AppColors.textSecondary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.black,
      elevation:       0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor:  AppColors.card,
    contentTextStyle: TextStyle(color: AppColors.textPrimary),
    behavior:         SnackBarBehavior.floating,
  ),
),
        // AuthWrapper decides which screen to show
        home: const AuthWrapper(),
      ),
    );
  }
}

// ── AUTH WRAPPER ───────────────────────────────────────────────────────────────
// Listens to Firebase login state and routes accordingly.
// This replaces the inline StreamBuilder from the earlier version.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Still connecting to Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return _LoggedInLoader(uid: snapshot.data!.uid);
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}

// Loads user data once after login, then shows the dashboard.
// Using a separate StatefulWidget prevents re-loading on every rebuild.
class _LoggedInLoader extends StatefulWidget {
  final String uid;
  const _LoggedInLoader({required this.uid});
  @override
  State<_LoggedInLoader> createState() => _LoggedInLoaderState();
}

class _LoggedInLoaderState extends State<_LoggedInLoader> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so providers are ready before we call them
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    await context.read<UserProvider>().loadUser(widget.uid);
    if (!mounted) return;
    context.read<FoodProvider>().listenToToday(widget.uid);
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Loading your profile...',
                style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return const DashboardScreen();
  }
}