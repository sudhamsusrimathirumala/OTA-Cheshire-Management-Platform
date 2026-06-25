import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtaColors.blush,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: OtaColors.blush,
        foregroundColor: OtaColors.ink,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: OtaColors.white,
              borderRadius: BorderRadius.circular(28),
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
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: OtaColors.softRed,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: OtaColors.maroon,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Profile Page Coming Soon',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const OtaBottomNavBar(
        selectedDestination: OtaBottomNavDestination.profile,
      ),
    );
  }
}
