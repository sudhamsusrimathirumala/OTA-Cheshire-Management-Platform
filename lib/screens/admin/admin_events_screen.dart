import 'package:flutter/material.dart';

import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderPage(
      title: 'Events',
      description: 'Create and update academy events and registration links.',
      selectedDestination: AdminNavDestination.events,
    );
  }
}
