import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'services/firestore/firestore_cleanup_service.dart';
import 'services/location_time_service.dart';

const bool enableFirestoreCleanupApply = false;
const String requiredConfirmationText = 'APPLY OTA FIRESTORE CLEANUP';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    runApp(const _CleanupReleaseRefusalApp());
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  LocationTimeService.initialize();
  runApp(const FirestoreCleanupApp());
}

class FirestoreCleanupApp extends StatelessWidget {
  const FirestoreCleanupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      title: 'Firestore Cleanup Planning',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const FirestoreCleanupScreen(),
    );
  }
}

class FirestoreCleanupScreen extends StatefulWidget {
  const FirestoreCleanupScreen({super.key});

  @override
  State<FirestoreCleanupScreen> createState() => _FirestoreCleanupScreenState();
}

class _FirestoreCleanupScreenState extends State<FirestoreCleanupScreen> {
  final _service = FirestoreCleanupService();
  final _confirmationController = TextEditingController();
  FirestoreCleanupPlan? _plan;
  PreparedFirestoreCleanup? _prepared;
  FirestoreCleanupResult? _result;
  Object? _error;
  bool _isBusy = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    setState(() {
      _isBusy = true;
      _error = null;
      _prepared = null;
      _result = null;
    });
    try {
      final plan = await _service.generatePlan();
      if (!mounted) return;
      setState(() => _plan = plan);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _copyJson(Object value, String message) async {
    final json = const JsonEncoder.withIndent('  ').convert(value);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _prepareBackup() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
      _prepared = null;
    });
    try {
      final prepared = await _service.prepareApply(plan);
      if (!mounted) return;
      setState(() => _prepared = prepared);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _apply() async {
    final prepared = _prepared;
    if (prepared == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final cleanup confirmation'),
        content: SingleChildScrollView(
          child: SelectableText(
            'Firebase project: ${prepared.plan.projectId}\n'
            'Affected documents: ${prepared.plan.affectedDocumentCount}\n'
            'Fields to set: ${prepared.plan.fieldsToSetCount}\n'
            'Fields to delete: ${prepared.plan.fieldsToDeleteCount}\n'
            'Unresolved issues: '
            '${prepared.plan.unresolvedFindings.length}\n'
            'Backup: ${prepared.backupPath}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply targeted updates'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final result = await _service.applyPrepared(
        prepared,
        enableApply: enableFirestoreCleanupApply,
        confirmationText: _confirmationController.text,
        requiredConfirmationText: requiredConfirmationText,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  bool get _confirmationMatches => isFirestoreCleanupConfirmationValid(
    _confirmationController.text,
    requiredConfirmationText: requiredConfirmationText,
  );

  bool get _canPrepare {
    final plan = _plan;
    return enableFirestoreCleanupApply &&
        !_isBusy &&
        plan != null &&
        plan.operations.isNotEmpty &&
        !plan.hasFailedPlannedOperationPreconditions &&
        _confirmationMatches;
  }

  bool get _canApply =>
      _canPrepare && _prepared != null && _prepared!.backupPath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final prepared = _prepared;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Cleanup Planning')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: enableFirestoreCleanupApply
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                enableFirestoreCleanupApply
                    ? 'WARNING: live cleanup apply mode is enabled.'
                    : 'Dry-run only. Live cleanup apply mode is disabled.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isBusy ? null : _generatePlan,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Generate Cleanup Plan'),
              ),
              OutlinedButton.icon(
                onPressed: plan == null
                    ? null
                    : () =>
                          _copyJson(plan.toJson(), 'Cleanup plan JSON copied.'),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Export Plan JSON'),
              ),
              OutlinedButton.icon(
                onPressed: _canPrepare ? _prepareBackup : null,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Prepare Local Backup'),
              ),
              FilledButton.icon(
                onPressed: _canApply ? _apply : null,
                icon: const Icon(Icons.playlist_add_check_circle_outlined),
                label: const Text('Apply Cleanup'),
              ),
              OutlinedButton.icon(
                onPressed: result == null
                    ? null
                    : () => _copyJson(
                        result.toJson(),
                        'Cleanup result JSON copied.',
                      ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Export Result JSON'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmationController,
            onChanged: (_) => setState(() {
              _prepared = null;
            }),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Exact apply confirmation',
              helperText: requiredConfirmationText,
            ),
          ),
          if (_isBusy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              'Operation failed: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (prepared != null) ...[
            const SizedBox(height: 16),
            SelectableText('Validated backup: ${prepared.backupPath}'),
          ],
          if (plan != null) ...[
            const SizedBox(height: 24),
            Text(
              'Dry-run plan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Project: ${plan.projectId}'),
            Text('Affected documents: ${plan.affectedDocumentCount}'),
            Text('Operations: ${plan.operations.length}'),
            Text('Fields to set: ${plan.fieldsToSetCount}'),
            Text('Fields to delete: ${plan.fieldsToDeleteCount}'),
            Text('Unresolved findings: ${plan.unresolvedFindings.length}'),
            Text('Warnings: ${plan.warnings.length}'),
            if (plan.sourceAuditIssueCount != null)
              Text('Before-audit issues: ${plan.sourceAuditIssueCount}'),
            const SizedBox(height: 12),
            for (final entry in plan.operationsByCollection.entries)
              ExpansionTile(
                title: Text(entry.key),
                subtitle: Text('${entry.value.length} operations'),
                children: [
                  for (final operation in entry.value)
                    ListTile(
                      title: Text(
                        '${operation.documentId} · '
                        '${operation.operationType.name}',
                      ),
                      subtitle: Text(
                        'Set: ${operation.fieldsToSet.keys.join(', ')}\n'
                        'Delete: ${operation.fieldsToDelete.join(', ')}\n'
                        '${operation.reason}',
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
            ExpansionTile(
              title: const Text('Unresolved decisions'),
              subtitle: Text('${plan.unresolvedFindings.length} findings'),
              children: [
                for (final finding in plan.unresolvedFindings)
                  ListTile(
                    title: Text('${finding.collection}/${finding.documentId}'),
                    subtitle: Text(
                      '${finding.message}\n${finding.recommendedAction}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 24),
            Text(
              result.success ? 'Cleanup completed' : 'Cleanup stopped',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Before issues: ${result.beforeIssueCount ?? 'unknown'}'),
            Text('After issues: ${result.afterIssueCount ?? 'not available'}'),
            Text('Applied operations: ${result.appliedOperationCount}'),
            SelectableText('Backup: ${result.backupPath}'),
            if (!result.success)
              SelectableText(
                'Failed at ${result.failedCollection}/'
                '${result.failedDocumentId}: ${result.errorMessage}',
              ),
            Text(
              'Remaining errors/warnings: '
              '${result.remainingErrorsAndWarnings.length}',
            ),
          ],
        ],
      ),
    );
  }
}

class _CleanupReleaseRefusalApp extends StatelessWidget {
  const _CleanupReleaseRefusalApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Firestore cleanup planning is development-only and cannot run '
              'in release mode.',
            ),
          ),
        ),
      ),
    );
  }
}
