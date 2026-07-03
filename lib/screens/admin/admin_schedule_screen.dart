import 'package:flutter/material.dart';

import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminScheduleScreen extends StatelessWidget {
  const AdminScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderPage(
      title: 'Schedule',
      description: 'Update class schedules shown to students and parents.',
      selectedDestination: AdminNavDestination.schedule,
    );
  }
}
