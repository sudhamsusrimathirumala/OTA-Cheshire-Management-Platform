import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debug/debug_mock_role_state.dart';
import '../theme/ota_colors.dart';

class DebugRoleSwitcher extends StatelessWidget {
  const DebugRoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DebugMockRole>(
      valueListenable: debugMockRoleState,
      builder: (context, selectedRole, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: OtaColors.navy.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OtaColors.white.withValues(alpha: 0.32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Debug role',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: OtaColors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<DebugMockRole>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return OtaColors.white;
                      }

                      return OtaColors.white.withValues(alpha: 0.08);
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return OtaColors.maroon;
                      }

                      return OtaColors.white;
                    }),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: OtaColors.white.withValues(alpha: 0.4)),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  segments: const [
                    ButtonSegment<DebugMockRole>(
                      value: DebugMockRole.student,
                      icon: Icon(Icons.school_outlined),
                      label: Text('Student'),
                    ),
                    ButtonSegment<DebugMockRole>(
                      value: DebugMockRole.admin,
                      icon: Icon(Icons.admin_panel_settings_outlined),
                      label: Text('Admin'),
                    ),
                  ],
                  selected: {selectedRole},
                  onSelectionChanged: (selection) {
                    final role = selection.single;
                    debugMockRoleState.switchTo(role);
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      debugMockRoleState.routeFor(role),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
