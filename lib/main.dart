import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import 'package:cloud_functions/cloud_functions.dart'; // Import Functions
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

// --- ADD THIS ---
// This boolean will control whether we use the local emulators or the live cloud
const bool USE_EMULATORS = true;
// --- END ADD ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- ADD THIS BLOCK ---
  if (USE_EMULATORS) {
    // Note: 10.0.2.2 is the special IP for 'localhost' on Android emulators
    // For iOS emulators, you can use 'localhost' or '127.0.0.1'
    // Let's use 127.0.0.1 as it works for both iOS and web/desktop.
    // If you are on an ANDROID emulator, change '127.0.0.1' to '10.0.2.2'

    const String host = '127.0.0.1';

    // Point Auth to the local emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Point Firestore to the local emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

    // Point Functions to the local emulator
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  }
  // --- END ADD ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Owo Health',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}
