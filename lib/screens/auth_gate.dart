import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        // Listen to the user's authentication state
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. If we are still waiting for data, show a loading spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. If the snapshot has data, a user is logged in
          if (snapshot.hasData) {
            // Show the main app
            return const HomeScreen();
          }

          // 3. If the snapshot has no data, no user is logged in
          // Show the login screen
          return const LoginScreen();
        },
      ),
    );
  }
}
