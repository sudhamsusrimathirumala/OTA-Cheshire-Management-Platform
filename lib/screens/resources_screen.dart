import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtaColors.blush,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: OtaColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: OtaColors.navy.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: OtaColors.softRed,
                        foregroundColor: OtaColors.maroon,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Icon(
                      Icons.folder_copy_rounded,
                      color: OtaColors.maroon,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Resources',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: OtaColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Student resources are coming soon.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Academy forms, curriculum links, testing information, and registration links will appear here.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const OtaBottomNavBar(
        selectedDestination: OtaBottomNavDestination.resources,
      ),
    );
  }
}
