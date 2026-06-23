import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';

class OtaBrandedScaffold extends StatelessWidget {
  const OtaBrandedScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtaColors.maroon,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ExcludeSemantics(
            child: CustomPaint(painter: _BrushStrokePainter()),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _BrushStrokePainter extends CustomPainter {
  const _BrushStrokePainter();

  static const Color _strokeColor = OtaColors.navy;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _strokeColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    paint.strokeWidth = size.shortestSide * 0.16;
    final topStroke = Path()
      ..moveTo(-size.width * 0.12, size.height * 0.16)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.04,
        size.width * 0.48,
        size.height * 0.12,
      );
    canvas.drawPath(topStroke, paint);

    paint.strokeWidth = size.shortestSide * 0.12;
    final sideStroke = Path()
      ..moveTo(size.width * 1.04, size.height * 0.32)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.36,
        size.width * 0.92,
        size.height * 0.55,
        size.width * 0.67,
        size.height * 0.59,
      );
    canvas.drawPath(sideStroke, paint);

    paint
      ..strokeWidth = size.shortestSide * 0.09
      ..color = _strokeColor.withValues(alpha: 0.75);
    final bottomStroke = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.73,
        size.width * 0.38,
        size.height * 0.88,
      );
    canvas.drawPath(bottomStroke, paint);
  }

  @override
  bool shouldRepaint(covariant _BrushStrokePainter oldDelegate) => false;
}
