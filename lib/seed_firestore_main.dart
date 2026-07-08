import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/firestore/firestore_migration_service.dart';

// Development-only entrypoint for manually migrating Firestore.
// This is not connected to the production app UI.
// This should not be used by normal users.
//
// Turn this off after the migration succeeds so this entrypoint cannot rerun it
// accidentally during normal development launches.
const bool _enableFirestoreMigration = true;

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
      title: 'Firestore Migration',
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
  bool _isRunning = false;
  String? _message;
  bool _hasError = false;

  Future<void> _runMigration() async {
    if (!_enableFirestoreMigration) {
      setState(() {
        _message =
            'Firestore migration is disabled. Set _enableFirestoreMigration to true to run it.';
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _message = null;
      _hasError = false;
    });

    try {
      await FirestoreMigrationService().runMvpReadinessMigration();

      if (!mounted) {
        return;
      }

      setState(() {
        _isRunning = false;
        _message =
            'Firestore migration complete. Turn _enableFirestoreMigration off before using this entrypoint again.';
        _hasError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRunning = false;
        _message = 'Firestore migration failed: $error';
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Migration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Firestore Migration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Runs merge/update-only MVP readiness changes. It does not wipe or fully reseed collections.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isRunning) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Running Firestore migration...'),
              ] else
                FilledButton(
                  onPressed: _enableFirestoreMigration ? _runMigration : null,
                  child: const Text('Run Migration'),
                ),
              if (!_enableFirestoreMigration) ...[
                const SizedBox(height: 12),
                const Text(
                  'Migration is currently disabled in code.',
                  textAlign: TextAlign.center,
                ),
              ],
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
