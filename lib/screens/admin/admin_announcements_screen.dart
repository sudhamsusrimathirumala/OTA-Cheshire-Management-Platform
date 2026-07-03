import 'package:flutter/material.dart';

import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminAnnouncementsScreen extends StatelessWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderPage(
      title: 'Announcements',
      description: 'Create announcements and notifications for families.',
      selectedDestination: AdminNavDestination.announcements,
    );
  }
}
