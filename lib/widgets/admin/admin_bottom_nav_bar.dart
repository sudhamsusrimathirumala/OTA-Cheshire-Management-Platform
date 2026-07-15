import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../models/academy_location.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/admin_location_controller.dart';
import '../../theme/ota_colors.dart';

void returnToAdminResourcesLanding(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushReplacementNamed(OtaRoutes.adminResources);
  }
}

enum AdminNavDestination {
  dashboard('Dashboard', OtaRoutes.adminDashboard, Icons.dashboard_outlined),
  students('Students', OtaRoutes.adminStudents, Icons.groups_outlined),
  announcements(
    'Announcements',
    OtaRoutes.adminAnnouncements,
    Icons.campaign_outlined,
  ),
  schedule('Schedule', OtaRoutes.adminSchedule, Icons.calendar_month_outlined),
  resources(
    'Events & Resources',
    OtaRoutes.adminResources,
    Icons.folder_copy_outlined,
  );

  const AdminNavDestination(this.label, this.route, this.icon);

  final String label;
  final String route;
  final IconData icon;
}

class AdminNavigationBar extends StatefulWidget {
  const AdminNavigationBar({
    required this.selectedDestination,
    this.onSelectedDestinationTap,
    super.key,
  });

  final AdminNavDestination selectedDestination;
  final VoidCallback? onSelectedDestinationTap;

  @override
  State<AdminNavigationBar> createState() => _AdminNavigationBarState();
}

class _AdminNavigationBarState extends State<AdminNavigationBar> {
  static double _savedScrollOffset = 0;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _savedScrollOffset,
    )..addListener(_saveScrollOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (_savedScrollOffset > maxScrollExtent) {
        _scrollController.jumpTo(maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_saveScrollOffset)
      ..dispose();
    super.dispose();
  }

  void _saveScrollOffset() {
    _savedScrollOffset = _scrollController.offset;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF7),
        border: Border(bottom: BorderSide(color: Color(0xFFE9D2D7))),
        boxShadow: [
          BoxShadow(
            color: Color(0x1C8B1E2D),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (final destination in AdminNavDestination.values)
              _AdminNavTab(
                destination: destination,
                isSelected: destination == widget.selectedDestination,
                onSelectedTap: destination == widget.selectedDestination
                    ? widget.onSelectedDestinationTap
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class AdminPageShell extends StatelessWidget {
  const AdminPageShell({
    required this.selectedDestination,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onSelectedDestinationTap,
    super.key,
  });

  final AdminNavDestination selectedDestination;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onSelectedDestinationTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminTopHeader(),
            AdminNavigationBar(
              selectedDestination: selectedDestination,
              onSelectedDestinationTap: onSelectedDestinationTap,
            ),
            Expanded(
              child: _AdminContentTransition(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AdminPageTitle(title: title, subtitle: subtitle),
                          const SizedBox(height: 18),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminContentTransition extends StatefulWidget {
  const _AdminContentTransition({required this.child});

  final Widget child;

  @override
  State<_AdminContentTransition> createState() =>
      _AdminContentTransitionState();
}

class _AdminContentTransitionState extends State<_AdminContentTransition> {
  var _isVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isVisible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _isVisible ? Offset.zero : const Offset(0, 0.015),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AdminPlaceholderPage extends StatelessWidget {
  const AdminPlaceholderPage({
    required this.selectedDestination,
    required this.title,
    required this.description,
    super.key,
  });

  final AdminNavDestination selectedDestination;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      selectedDestination: selectedDestination,
      title: title,
      subtitle: description,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF8),
          border: Border(
            top: BorderSide(color: Color(0xFFE9D2D7)),
            bottom: BorderSide(color: Color(0xFFE9D2D7)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(width: 3, height: 32, color: OtaColors.maroon),
              const SizedBox(width: 12),
              Icon(selectedDestination.icon, color: OtaColors.maroon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kept as an alias so existing admin screens can migrate without route churn.
typedef AdminBottomNavBar = AdminNavigationBar;

class AdminTopHeader extends StatelessWidget {
  const AdminTopHeader({this.controller, super.key});

  final AdminLocationController? controller;

  @override
  Widget build(BuildContext context) {
    final locationController = controller ?? adminLocationController;
    return AnimatedBuilder(
      animation: locationController,
      builder: (context, _) => _buildHeader(context, locationController),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AdminLocationController locationController,
  ) {
    final presentation = adminHeaderPresentation(locationController);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF0EA)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OtaColors.maroon, OtaColors.actionRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFDCA6AE)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: OtaColors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: OtaColors.ink,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      presentation.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  border: Border.all(color: const Color(0xFFE9D28E)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  presentation.badge,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  Navigator.of(context).pushNamed(OtaRoutes.adminProfile);
                },
                style: IconButton.styleFrom(
                  backgroundColor: OtaColors.white,
                  foregroundColor: OtaColors.maroon,
                  side: const BorderSide(color: Color(0xFFE9D2D7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                icon: const Icon(Icons.person_outline_rounded),
                tooltip: 'Admin profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminHeaderPresentation {
  const AdminHeaderPresentation({
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final String title;
  final String subtitle;
  final String badge;
}

AdminHeaderPresentation adminHeaderPresentation(
  AdminLocationController controller,
) {
  if (controller.isDebugAdmin) {
    return const AdminHeaderPresentation(
      title: 'OTA Cheshire',
      subtitle: 'Sample Admin View',
      badge: 'Development Mock Data',
    );
  }
  if (controller.isSuperAdmin) {
    final selected = controller.selectedLocation;
    return AdminHeaderPresentation(
      title: 'OTA Administration',
      subtitle: selected?.name ?? 'All locations',
      badge: selected == null
          ? 'Select a location for edits'
          : _locationSecondaryText(selected),
    );
  }
  final assigned = controller.assignedLocation;
  return AdminHeaderPresentation(
    title: assigned?.name ?? 'OTA Administration',
    subtitle: assigned == null
        ? 'Academy location unavailable'
        : assigned.isActive
        ? _locationSecondaryText(assigned)
        : 'Academy unavailable',
    badge: 'Location Admin',
  );
}

String _locationSecondaryText(AcademyLocation location) {
  final address = location.formattedAddress;
  return address.isEmpty ? location.id : address.replaceAll('\n', ', ');
}

class _AdminPageTitle extends StatelessWidget {
  const _AdminPageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: OtaColors.ink,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OtaColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AdminNavTab extends StatelessWidget {
  const _AdminNavTab({
    required this.destination,
    required this.isSelected,
    this.onSelectedTap,
  });

  final AdminNavDestination destination;
  final bool isSelected;
  final VoidCallback? onSelectedTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isSelected
          ? onSelectedTap
          : () {
              Navigator.of(context).pushReplacementNamed(destination.route);
            },
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? OtaColors.white : OtaColors.ink,
        disabledForegroundColor: OtaColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: isSelected ? OtaColors.maroon : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 17),
              const SizedBox(width: 6),
              Text(destination.label),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2,
            width: isSelected ? 28 : 0,
            color: const Color(0xFFFFC857),
          ),
        ],
      ),
    );
  }
}
