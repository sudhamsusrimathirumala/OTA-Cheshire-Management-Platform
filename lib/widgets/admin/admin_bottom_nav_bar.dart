import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme/ota_colors.dart';

enum AdminNavDestination {
  dashboard,
  students,
  events,
  announcements,
  schedule,
}

class AdminBottomNavBar extends StatelessWidget {
  const AdminBottomNavBar({required this.selectedDestination, super.key});

  final AdminNavDestination selectedDestination;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedDestination.index,
      indicatorColor: OtaColors.softRed,
      backgroundColor: OtaColors.white,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups_rounded),
          label: 'Students',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event_rounded),
          label: 'Events',
        ),
        NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign_rounded),
          label: 'Announcements',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Schedule',
        ),
      ],
      onDestinationSelected: (index) {
        final destination = AdminNavDestination.values[index];

        if (destination == selectedDestination) {
          return;
        }

        switch (destination) {
          case AdminNavDestination.dashboard:
            Navigator.of(
              context,
            ).pushReplacementNamed(OtaRoutes.adminDashboard);
          case AdminNavDestination.students:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.adminStudents);
          case AdminNavDestination.events:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.adminEvents);
          case AdminNavDestination.announcements:
            Navigator.of(
              context,
            ).pushReplacementNamed(OtaRoutes.adminAnnouncements);
          case AdminNavDestination.schedule:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.adminSchedule);
        }
      },
    );
  }
}
