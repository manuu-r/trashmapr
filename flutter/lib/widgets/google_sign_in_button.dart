import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SizedBox(
        width: 280,
        height: 56,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? Colors.white : Colors.white,
            foregroundColor: const Color(0xFF1F1F1F),
            elevation: 2,
            shadowColor: Colors.black26,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google Logo
                    _GoogleLogo(),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF1F1F1F),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scale the 48x48 SVG to fit the widget size
    final scale = size.width / 48.0;
    canvas.scale(scale);

    final paint = Paint()..style = PaintingStyle.fill;

    // Yellow path (top)
    paint.color = const Color(0xFFFFC107);
    final yellowPath = Path();
    yellowPath.moveTo(43.611, 20.083);
    yellowPath.lineTo(42, 20.083);
    yellowPath.lineTo(42, 20);
    yellowPath.lineTo(24, 20);
    yellowPath.lineTo(24, 28);
    yellowPath.lineTo(35.303, 28);
    yellowPath.cubicTo(33.654, 32.657, 29.223, 36, 24, 36);
    yellowPath.cubicTo(17.373, 36, 12, 30.627, 12, 24);
    yellowPath.cubicTo(12, 17.373, 17.373, 12, 24, 12);
    yellowPath.cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039);
    yellowPath.lineTo(37.618, 9.382);
    yellowPath.cubicTo(34.046, 6.053, 29.268, 4, 24, 4);
    yellowPath.cubicTo(12.955, 4, 4, 12.955, 4, 24);
    yellowPath.cubicTo(4, 35.045, 12.955, 44, 24, 44);
    yellowPath.cubicTo(35.045, 44, 44, 35.045, 44, 24);
    yellowPath.cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083);
    yellowPath.close();
    canvas.drawPath(yellowPath, paint);

    // Red path (top-left)
    paint.color = const Color(0xFFFF3D00);
    final redPath = Path();
    redPath.moveTo(6.306, 14.691);
    redPath.lineTo(12.877, 19.51);
    redPath.cubicTo(14.655, 15.108, 18.961, 12, 24, 12);
    redPath.cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039);
    redPath.lineTo(37.618, 9.382);
    redPath.cubicTo(34.046, 6.053, 29.268, 4, 24, 4);
    redPath.cubicTo(16.318, 4, 9.656, 8.337, 6.306, 14.691);
    redPath.close();
    canvas.drawPath(redPath, paint);

    // Green path (bottom)
    paint.color = const Color(0xFF4CAF50);
    final greenPath = Path();
    greenPath.moveTo(24, 44);
    greenPath.cubicTo(29.166, 44, 33.86, 42.023, 37.409, 38.808);
    greenPath.lineTo(31.219, 33.57);
    greenPath.cubicTo(29.211, 35.091, 26.715, 36, 24, 36);
    greenPath.cubicTo(18.798, 36, 14.381, 32.683, 12.717, 28.054);
    greenPath.lineTo(6.195, 33.079);
    greenPath.cubicTo(9.505, 39.556, 16.227, 44, 24, 44);
    greenPath.close();
    canvas.drawPath(greenPath, paint);

    // Blue path (right)
    paint.color = const Color(0xFF1976D2);
    final bluePath = Path();
    bluePath.moveTo(43.611, 20.083);
    bluePath.lineTo(42, 20.083);
    bluePath.lineTo(42, 20);
    bluePath.lineTo(24, 20);
    bluePath.lineTo(24, 28);
    bluePath.lineTo(35.303, 28);
    bluePath.cubicTo(34.511, 30.237, 33.072, 32.166, 31.216, 33.571);
    bluePath.cubicTo(31.217, 33.57, 31.218, 33.57, 31.219, 33.569);
    bluePath.lineTo(37.409, 38.807);
    bluePath.cubicTo(36.971, 39.205, 44, 34, 44, 24);
    bluePath.cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083);
    bluePath.close();
    canvas.drawPath(bluePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
