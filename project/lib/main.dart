import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/playlist_provider.dart';
import 'pages/auth_gate.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PlaylistProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Melodify',
      // Pass the analytics observer so screen_view events fire automatically
      // when Navigator routes change.
      navigatorObservers: [AnalyticsService.observer],
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB388FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
