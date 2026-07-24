import 'package:flutter/material.dart';

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
