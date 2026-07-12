import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/firestore/firestore_schema_update_service.dart';

const bool enableApprovedSchemaUpdate = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ApprovedSchemaUpdateApp());
}

class ApprovedSchemaUpdateApp extends StatelessWidget {
  const ApprovedSchemaUpdateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: true,
      home: ApprovedSchemaUpdateScreen(),
    );
  }
}

class ApprovedSchemaUpdateScreen extends StatefulWidget {
  const ApprovedSchemaUpdateScreen({super.key});

  @override
  State<ApprovedSchemaUpdateScreen> createState() =>
      _ApprovedSchemaUpdateScreenState();
}

class _ApprovedSchemaUpdateScreenState
    extends State<ApprovedSchemaUpdateScreen> {
  bool _isRunning = false;
  String? _message;

  Future<void> _apply() async {
    if (!kDebugMode || !enableApprovedSchemaUpdate) return;
    setState(() {
      _isRunning = true;
      _message = null;
    });
    try {
      final count = await FirestoreSchemaUpdateService().applyApprovedUpdates();
      if (!mounted) return;
      setState(() => _message = 'Applied $count targeted document updates.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Schema update failed: $error');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = kDebugMode && enableApprovedSchemaUpdate && !_isRunning;
    return Scaffold(
      appBar: AppBar(title: const Text('Approved Schema Updates')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: enabled ? _apply : null,
                child: Text(
                  _isRunning ? 'Applying...' : 'Apply Approved Schema Updates',
                ),
              ),
              if (!enableApprovedSchemaUpdate) ...[
                const SizedBox(height: 12),
                const Text('Schema update is disabled in code.'),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
