import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/firestore/firestore_seed_service.dart';

// Development-only entrypoint for manually seeding Firestore.
// This is not connected to the production app UI.
// This should not be used by normal users.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SeedFirestoreApp());
}

class SeedFirestoreApp extends StatelessWidget {
  const SeedFirestoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Firestore Seeder',
      debugShowCheckedModeBanner: false,
      home: _SeedFirestoreScreen(),
    );
  }
}

class _SeedFirestoreScreen extends StatefulWidget {
  const _SeedFirestoreScreen();

  @override
  State<_SeedFirestoreScreen> createState() => _SeedFirestoreScreenState();
}

class _SeedFirestoreScreenState extends State<_SeedFirestoreScreen> {
  bool _isSeeding = false;
  String? _message;
  bool _hasError = false;

  Future<void> _seedFirestore() async {
    setState(() {
      _isSeeding = true;
      _message = null;
      _hasError = false;
    });

    try {
      await FirestoreSeedService().seedAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSeeding = false;
        _message = 'Firestore seed complete.';
        _hasError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSeeding = false;
        _message = 'Firestore seed failed: $error';
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Seeder')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Firestore Seeder',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              if (_isSeeding) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Seeding Firestore...'),
              ] else
                FilledButton(
                  onPressed: _seedFirestore,
                  child: const Text('Seed Firestore'),
                ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _hasError ? colorScheme.error : colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
