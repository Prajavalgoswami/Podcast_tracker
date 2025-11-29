import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/local_storage_service.dart';
import 'core/services/api_services.dart';
import 'core/services/audio_player_service.dart';
import 'core/themes/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/podcast_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local storage
  await LocalStorageService().initialize();

  // Initialize API service
  ApiService().initialize();

  // Initialize audio player
  await AudioPlayerService().initialize();

  // Initialize providers
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  
  final audioProvider = AudioProvider();
  await audioProvider.initialize();

  runApp(MyApp(themeProvider: themeProvider, audioProvider: audioProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final AudioProvider audioProvider;
  
  const MyApp({super.key, required this.themeProvider, required this.audioProvider});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => PodcastProvider()),
            ChangeNotifierProvider.value(value: audioProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: Consumer2<AuthProvider, ThemeProvider>(
            builder: (context, authProvider, themeProvider, _) {
              // Set audio provider reference for auto-pause on logout
              authProvider.setAudioProvider(audioProvider);
              
              return MaterialApp(
                title: 'Podcast Tracker',
                debugShowCheckedModeBanner: false,

                // Theme
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,

                // Localization
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en', ''), // English
                  Locale('es', ''), // Spanish
                  Locale('fr', ''), // French
                  Locale('de', ''), // German
                  Locale('hi', ''), // Hindi
                  Locale('ar', ''), // Arabic
                ],
                locale: Locale(themeProvider.selectedLanguage),

                // Home
                home: const SplashScreen(),
              );
            },
          ),
        );
      },
    );
  }
}