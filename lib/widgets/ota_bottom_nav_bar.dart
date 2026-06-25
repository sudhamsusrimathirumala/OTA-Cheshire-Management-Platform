import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/ota_colors.dart';

enum OtaBottomNavDestination {
  dashboard,
  schedule,
  curriculum,
  notifications,
  profile,
}

class OtaBottomNavBar extends StatelessWidget {
  const OtaBottomNavBar({required this.selectedDestination, super.key});

  final OtaBottomNavDestination selectedDestination;

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
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Curriculum',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: 'Notifications',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
      onDestinationSelected: (index) {
        final destination = OtaBottomNavDestination.values[index];

        if (destination == selectedDestination) {
          return;
        }

        switch (destination) {
          case OtaBottomNavDestination.dashboard:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.dashboard);
          case OtaBottomNavDestination.schedule:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.schedule);
          case OtaBottomNavDestination.curriculum:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.curriculum);
          case OtaBottomNavDestination.notifications:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.notifications);
          case OtaBottomNavDestination.profile:
            Navigator.of(context).pushReplacementNamed(OtaRoutes.profile);
        }
      },
    );
  }
}
