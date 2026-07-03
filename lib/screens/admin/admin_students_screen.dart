import 'package:flutter/material.dart';

import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminStudentsScreen extends StatelessWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminPlaceholderScaffold(
      title: 'Students',
      description: 'Search and view student profiles.',
      icon: Icons.groups_outlined,
      selectedDestination: AdminNavDestination.students,
    );
  }
}

class _AdminPlaceholderScaffold extends StatelessWidget {
  const _AdminPlaceholderScaffold({
    required this.title,
    required this.description,
    required this.icon,
    required this.selectedDestination,
  });

  final String title;
  final String description;
  final IconData icon;
  final AdminNavDestination selectedDestination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: OtaColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE1E4EA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: OtaColors.softRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: OtaColors.maroon),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: OtaColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: OtaColors.mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNavBar(
        selectedDestination: selectedDestination,
      ),
    );
  }
}
