import 'package:flutter/material.dart';

import '../../services/firebase/firebase_session_controller.dart';
import '../../theme/ota_colors.dart';

class AccountReadyScreen extends StatelessWidget {
  const AccountReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = firebaseSessionController;
    return Scaffold(
      backgroundColor: OtaColors.blush,
      appBar: AppBar(title: const Text('Your account is ready')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 58,
                      color: OtaColors.maroon,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your account is ready',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 18),
                    _ReadyDetail(
                      label: 'Academy location',
                      value:
                          session.selectedLocationName ??
                          session.account?.locationId ??
                          'Academy location',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Student profiles',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final profile in session.profiles)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(profile.name),
                        subtitle: Text(profile.beltRank),
                      ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: session.dismissCreatedConfirmation,
                      child: const Text('Continue to Dashboard'),
                    ),
                    TextButton(
                      onPressed: session.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyDetail extends StatelessWidget {
  const _ReadyDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 150,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: OtaColors.mutedText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}
