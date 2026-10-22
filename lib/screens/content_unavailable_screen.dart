import 'package:flutter/material.dart';

class ContentStatusPanel extends StatelessWidget {
  const ContentStatusPanel({
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading item…'),
          ] else ...[
            Text(
              errorMessage == null
                  ? 'This item is no longer available.'
                  : 'Unable to load this item. Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              FilledButton(onPressed: onRetry, child: const Text('Retry'))
            else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
          ],
        ],
      ),
    ),
  );
}

class ContentUnavailableScreen extends StatelessWidget {
  const ContentUnavailableScreen({required this.returnRoute, super.key});

  final String returnRoute;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Item unavailable')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hide_source_rounded, size: 48),
            const SizedBox(height: 16),
            const Text(
              'This item is no longer available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(returnRoute),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    ),
  );
}
