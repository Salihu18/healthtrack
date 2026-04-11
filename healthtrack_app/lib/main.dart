import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'providers/user_provider.dart';
import 'providers/food_provider.dart';
import 'providers/weight_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);

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
        title:                     'HealthTrack',
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
          cardTheme: const CardThemeData(
            color:     AppColors.card,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled:    true,
            fillColor: AppColors.surface,
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
              borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5),
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
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   16),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor:  AppColors.card,
            contentTextStyle: TextStyle(color: AppColors.textPrimary),
            behavior:         SnackBarBehavior.floating,
          ),
        ),
        home:  SplashScreen(),
      ),
    );
  }
}