import 'dart:io';

import 'package:fiveyear/services/notification_service.dart';
import 'package:fiveyear/ui/screens/daily_checkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'ui/home_screen.dart';

Future<void> initializeRevenueCat() async {
  // Platform-specific API keys
  String apiKey;
  if (Platform.isIOS) {
    apiKey = 'appl_ilGImMrklPJWeVLyoNkZUllnHfp';
  } else if (Platform.isAndroid) {
    apiKey = 'goog_CbsVMNhxTnVdauUYFBhnpNlwBXv';
  } else {
    throw UnsupportedError('Platform not supported');
  }

  await Purchases.configure(PurchasesConfiguration(apiKey));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notifications and capture payload if launched from notification
  final container = ProviderContainer();
  final String? initialPayload = await container
      .read(notificationServiceProvider)
      .init();

  await initializeRevenueCat();
  
  await FlutterGemma.initialize();

  // 1. Enable Edge-to-Edge (Android 10+)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 2. Wrap app in ProviderScope and pass the payload
  runApp(ProviderScope(child: MyApp(initialPayload: initialPayload)));
}

class MyApp extends StatelessWidget {
  final String? initialPayload;

  const MyApp({super.key, this.initialPayload});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '5Y',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // 1. LIGHT THEME
      theme: ThemeData(
        // REC: Use BlueGrey or a specific brand color instead of White for the seed
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 97, 154, 74),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Your custom warm off-white is good!
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // 2. DARK THEME
      darkTheme: ThemeData(
        // REC: Use the same seed as light mode so the brand identity matches
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 97, 154, 74),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // REC: Use #121212 for better shadow visibility and less eye strain
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // 3. AUTO-DETECT
      themeMode: ThemeMode.system,

      // If payload is present, start there; otherwise start at home
      initialRoute: initialPayload == 'daily_check_in'
          ? '/daily_check_in'
          : '/',

      routes: {
        '/': (context) => const HomeScreen(),
        '/daily_check_in': (context) => const DailyCheckInScreen(),
      },
    );
  }
}
