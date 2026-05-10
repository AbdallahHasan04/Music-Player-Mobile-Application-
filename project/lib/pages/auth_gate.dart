import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'playlist_provider.dart';
import 'login_page.dart';
import 'home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F1A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFB388FF)),
            ),
          );
        }

        // Logged in — reload this user's custom songs
        if (snapshot.hasData) {
          // Use addPostFrameCallback so the widget tree is fully built first
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<PlaylistProvider>(context, listen: false)
                .reloadCustomSongs();
          });
          return const MyHomePage();
        }

        // Not logged in
        return const LoginPage();
      },
    );
  }
}