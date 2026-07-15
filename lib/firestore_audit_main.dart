import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options_dev.dart';
import 'services/firestore/firestore_audit_service.dart';
import 'services/location_time_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    runApp(const _ReleaseModeRefusalApp());
    return;
  }
  await Firebase.initializeApp(
    options: DevelopmentFirebaseOptions.currentPlatform,
  );
  LocationTimeService.initialize();
  runApp(const FirestoreAuditApp());
}

class FirestoreAuditApp extends StatelessWidget {
  const FirestoreAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      title: 'Firestore Audit',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const FirestoreAuditScreen(),
    );
  }
}

class FirestoreAuditScreen extends StatefulWidget {
  const FirestoreAuditScreen({super.key, this._auditService});

  final FirestoreAuditService? _auditService;

  @override
  State<FirestoreAuditScreen> createState() => _FirestoreAuditScreenState();
}

class _FirestoreAuditScreenState extends State<FirestoreAuditScreen> {
  bool _isRunning = false;
  FirestoreAuditReport? _report;
  Object? _error;

  Future<void> _runAudit() async {
    setState(() {
      _isRunning = true;
      _error = null;
    });
    try {
      final report = await (widget._auditService ?? FirestoreAuditService())
          .run();
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null) return;
    final json = const JsonEncoder.withIndent('  ').convert(report.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON report copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Audit')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This audit does not modify Firestore.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isRunning ? null : _runAudit,
                icon: _isRunning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: const Text('Run Read-Only Audit'),
              ),
              OutlinedButton.icon(
                onPressed: report == null ? null : _copyReport,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy JSON Report'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              'Audit failed: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 24),
            Text(
              'Total issues: ${report.totalIssueCount}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final collection in report.collections)
                  Chip(
                    label: Text(
                      '${collection.collection}: ${collection.issues.length}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in report.countsBySeverity.entries)
                  Chip(label: Text('${entry.key.name}: ${entry.value}')),
              ],
            ),
            const SizedBox(height: 16),
            for (final collection in report.collections)
              ExpansionTile(
                title: Text(collection.collection),
                subtitle: Text(
                  '${collection.documentCount} documents, '
                  '${collection.issues.length} issues',
                ),
                children: [
                  if (collection.issues.isEmpty)
                    const ListTile(title: Text('No issues detected.')),
                  for (final issue in collection.issues)
                    ListTile(
                      leading: Icon(_severityIcon(issue.severity)),
                      title: Text('${issue.documentId} · ${issue.issueCode}'),
                      subtitle: Text(
                        '${issue.message}\n${issue.recommendedAction}',
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

IconData _severityIcon(FirestoreAuditSeverity severity) => switch (severity) {
  FirestoreAuditSeverity.info => Icons.info_outline,
  FirestoreAuditSeverity.warning => Icons.warning_amber_outlined,
  FirestoreAuditSeverity.error => Icons.error_outline,
};

class _ReleaseModeRefusalApp extends StatelessWidget {
  const _ReleaseModeRefusalApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Firestore Audit is development-only and cannot run in release mode.',
            ),
          ),
        ),
      ),
    );
  }
}
