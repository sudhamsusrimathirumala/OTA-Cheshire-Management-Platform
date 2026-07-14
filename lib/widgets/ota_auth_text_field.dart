import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';

class OtaAuthTextField extends StatelessWidget {
  const OtaAuthTextField({
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.controller,
    this.validator,
    this.suffixIcon,
    this.autofillHints,
    this.onFieldSubmitted,
    super.key,
  });

  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: OtaColors.navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: OtaColors.navy.withValues(alpha: 0.72)),
        filled: true,
        fillColor: OtaColors.white.withValues(alpha: 0.96),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: OtaColors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: OtaColors.white, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        suffixIcon: suffixIcon,
        errorStyle: const TextStyle(color: Color(0xFFFFD8D8)),
      ),
    );
  }
}
