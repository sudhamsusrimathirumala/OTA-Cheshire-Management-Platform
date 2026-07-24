import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options_dev.dart';
import 'services/firestore/firestore_export_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    runApp(const _ReleaseModeRefusalApp());
    return;
  }
  await Firebase.initializeApp(
    options: DevelopmentFirebaseOptions.currentPlatform,
  );
  runApp(const FirestoreExportApp());
}

class FirestoreExportApp extends StatelessWidget {
  const FirestoreExportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      title: 'Firestore Export',
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: const FirestoreExportScreen(),
    );
  }
}

class FirestoreExportScreen extends StatefulWidget {
  const FirestoreExportScreen({super.key});

  @override
  State<FirestoreExportScreen> createState() => _FirestoreExportScreenState();
}

class _FirestoreExportScreenState extends State<FirestoreExportScreen> {
  final _service = FirestoreExportService();
  final _jsonController = TextEditingController();
  final _scrollController = ScrollController();
  FirestoreDatabaseExport? _export;
  Object? _error;
  bool _isReading = false;

  @override
  void dispose() {
    _jsonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _readDatabase() async {
    setState(() {
      _isReading = true;
      _error = null;
    });
    try {
      final export = await _service.readDatabase();
      if (!mounted) return;
      setState(() {
        _export = export;
        _jsonController.text = export.toPrettyJson();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  Future<void> _copyJson() async {
    if (_export == null) return;
    await Clipboard.setData(ClipboardData(text: _jsonController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Export JSON copied.')));
  }

  Future<void> _saveJson() async {
    if (_export == null) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Firestore export',
        fileName: 'firestore_export.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(_jsonController.text)),
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export saved: $path')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final export = _export;
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Export')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isReading ? null : _readDatabase,
                  icon: _isReading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: const Text('Read Database'),
                ),
                OutlinedButton.icon(
                  onPressed: export == null ? null : _copyJson,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: export == null ? null : _saveJson,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Save JSON'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                'Export failed: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (export != null) ...[
              const SizedBox(height: 12),
              Text('Project ID: ${export.projectId}'),
              Text('Export time: ${export.exportedAt.toLocal()}'),
              Text('Document count: ${export.documentCount}'),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in export.collectionCounts.entries)
                    Chip(label: Text('${entry.key}: ${entry.value}')),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: TextField(
                  controller: _jsonController,
                  scrollController: _scrollController,
                  readOnly: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        'Select Read Database to generate the JSON export.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseModeRefusalApp extends StatelessWidget {
  const _ReleaseModeRefusalApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Firestore Export is development-only and cannot run in release mode.',
          ),
        ),
      ),
    );
  }
}
