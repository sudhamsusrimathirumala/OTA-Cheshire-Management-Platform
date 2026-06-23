import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';

class OtaAuthSwitchLink extends StatelessWidget {
  const OtaAuthSwitchLink({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            prompt,
            style: TextStyle(color: OtaColors.white.withValues(alpha: 0.88)),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: OtaColors.white),
          child: Text(action),
        ),
      ],
    );
  }
}
