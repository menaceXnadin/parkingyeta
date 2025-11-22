import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parking_details_screen.dart';
import 'screens/add_parking_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/signup_screen.dart';
import 'providers/parking_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/auth_wrapper.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging to reduce verbose output
  if (kReleaseMode) {
    // Disable debug prints in release mode
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  try {
    // Initialize Firebase with error handling
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization error: $e');
    }
  }

  // Create and initialize the ParkingProvider with error handling
  final parkingProvider = ParkingProvider();
  try {
    await parkingProvider.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('ParkingProvider initialization error: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => parkingProvider),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const SajiloParking(),
    ),
  );
}

class SajiloParking extends StatelessWidget {
  const SajiloParking({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Show loading indicator if the ThemeProvider is not yet initialized
        if (!themeProvider.isInitialized) {
          return MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return AnimatedTheme(
          duration: const Duration(milliseconds: 300),
          data: themeProvider.isDarkMode
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          child: MaterialApp(
            title: 'Sajilo Parking',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeInOut,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/details': (context) => const ParkingDetailsScreen(),
              '/add': (context) => const AddParkingScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/signup': (context) => const SignUpScreen(),
            },
          ),
        );
      },
    );
  }
}
