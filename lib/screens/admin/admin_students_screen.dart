import 'package:flutter/material.dart';

import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminStudentsScreen extends StatelessWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderPage(
      title: 'Students',
      description: 'Search and view student profiles.',
      selectedDestination: AdminNavDestination.students,
    );
  }
}
