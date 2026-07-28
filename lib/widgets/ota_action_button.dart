import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';

enum OtaActionButtonVariant { primary, secondary }

class OtaActionButton extends StatelessWidget {
  const OtaActionButton({
    required this.label,
    required this.onPressed,
    this.variant = OtaActionButtonVariant.primary,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final OtaActionButtonVariant variant;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final isSecondary = variant == OtaActionButtonVariant.secondary;
    final child = _ButtonLabel(label: label, icon: icon);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    final fixedStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(58)),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );

    if (isSecondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: OtaColors.white,
          side: const BorderSide(color: OtaColors.white, width: 1.5),
        ).merge(fixedStyle),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: OtaColors.actionRed,
        foregroundColor: OtaColors.white,
        elevation: 8,
        shadowColor: OtaColors.navy.withValues(alpha: 0.55),
      ).merge(fixedStyle),
      child: child,
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon});

  final String label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(label);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        icon!,
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}
