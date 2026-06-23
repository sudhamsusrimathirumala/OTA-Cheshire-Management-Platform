import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';

class OtaLogoMark extends StatelessWidget {
  const OtaLogoMark({this.size, this.isCompact = false, super.key});

  final double? size;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? (isCompact ? 124.0 : 168.0);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: const BoxDecoration(
        color: OtaColors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image(
          image: const AssetImage('assets/images/ota_logo.png'),
          fit: BoxFit.contain,
          semanticLabel: 'Olympic Taekwondo Academy logo',
        ),
      ),
    );
  }
}
