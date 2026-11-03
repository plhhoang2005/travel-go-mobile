import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Linh vật GoAI - Trợ lý du lịch TravelGO
/// Được vẽ bằng CustomPainter vector thuần Flutter, không phụ thuộc vào file ảnh ngoài.
/// Có hình chú sóc/cáo con màu xanh bạc hà đội nón tai bèo safari và ba lô du lịch,
/// luôn tươi cười đồng hành cùng người dùng.
class GoAiMascot extends StatelessWidget {
  final double size;
  final bool isWaving;
  final bool withShadow;

  const GoAiMascot({
    super.key,
    this.size = 48,
    this.isWaving = false,
    this.withShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: withShadow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.tealPrimary.withValues(alpha: 0.18),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            )
          : null,
      child: CustomPaint(
        painter: _GoAiPainter(isWaving: isWaving),
        size: Size(size, size),
      ),
    );
  }
}

class _GoAiPainter extends CustomPainter {
  final bool isWaving;

  _GoAiPainter({required this.isWaving});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Vòng tròn nền mềm (Soft Mint/Teal background circle)
    final bgPaint = Paint()
      ..color = const Color(0xFFE0F2F1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, w * 0.48, bgPaint);

    final borderPaint = Paint()
      ..color = AppTheme.tealPrimary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;
    canvas.drawCircle(center, w * 0.48, borderPaint);

    // 2. Tai linh vật (Ears)
    final earPaint = Paint()
      ..color = const Color(0xFF0A8A7A)
      ..style = PaintingStyle.fill;
    final innerEarPaint = Paint()
      ..color = const Color(0xFFFFB4A2)
      ..style = PaintingStyle.fill;

    // Tai trái
    final leftEarPath = Path()
      ..moveTo(w * 0.26, h * 0.36)
      ..lineTo(w * 0.18, h * 0.18)
      ..lineTo(w * 0.36, h * 0.25)
      ..close();
    canvas.drawPath(leftEarPath, earPaint);

    final leftInnerEar = Path()
      ..moveTo(w * 0.27, h * 0.33)
      ..lineTo(w * 0.22, h * 0.21)
      ..lineTo(w * 0.34, h * 0.26)
      ..close();
    canvas.drawPath(leftInnerEar, innerEarPaint);

    // Tai phải
    final rightEarPath = Path()
      ..moveTo(w * 0.74, h * 0.36)
      ..lineTo(w * 0.82, h * 0.18)
      ..lineTo(w * 0.64, h * 0.25)
      ..close();
    canvas.drawPath(rightEarPath, earPaint);

    final rightInnerEar = Path()
      ..moveTo(w * 0.73, h * 0.33)
      ..lineTo(w * 0.78, h * 0.21)
      ..lineTo(w * 0.66, h * 0.26)
      ..close();
    canvas.drawPath(rightInnerEar, innerEarPaint);

    // 3. Khuôn mặt chính (Face)
    final facePaint = Paint()
      ..color = const Color(0xFF086C61)
      ..style = PaintingStyle.fill;
    final faceRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.52),
      width: w * 0.62,
      height: h * 0.52,
    );
    canvas.drawOval(faceRect, facePaint);

    // Vùng má trắng sáng (Cheeks/Muzzle)
    final muzzlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final leftCheek = Rect.fromCenter(
      center: Offset(w * 0.40, h * 0.57),
      width: w * 0.25,
      height: h * 0.26,
    );
    final rightCheek = Rect.fromCenter(
      center: Offset(w * 0.60, h * 0.57),
      width: w * 0.25,
      height: h * 0.26,
    );
    canvas.drawOval(leftCheek, muzzlePaint);
    canvas.drawOval(rightCheek, muzzlePaint);

    // 4. Mũ Safari (Safari Explorer Hat)
    final hatBrimPaint = Paint()
      ..color = const Color(0xFFD4A373)
      ..style = PaintingStyle.fill;
    final hatBrimRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.30),
      width: w * 0.72,
      height: h * 0.14,
    );
    canvas.drawOval(hatBrimRect, hatBrimPaint);

    final hatCrownPaint = Paint()
      ..color = const Color(0xFFBC6C25)
      ..style = PaintingStyle.fill;
    final hatCrownRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.23),
        width: w * 0.44,
        height: h * 0.18,
      ),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(hatCrownRect, hatCrownPaint);

    // Dải ruy băng mũ (Hat ribbon)
    final ribbonPaint = Paint()
      ..color = const Color(0xFF086C61)
      ..style = PaintingStyle.fill;
    final ribbonRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.28),
      width: w * 0.45,
      height: h * 0.04,
    );
    canvas.drawRect(ribbonRect, ribbonPaint);

    // 5. Đôi mắt to tròn long lanh (Sparkling Eyes)
    final eyePaint = Paint()
      ..color = const Color(0xFF132A13)
      ..style = PaintingStyle.fill;
    final eyeGlintPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Mắt trái
    canvas.drawCircle(Offset(w * 0.38, h * 0.48), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(w * 0.365, h * 0.465), w * 0.022, eyeGlintPaint);

    // Mắt phải
    canvas.drawCircle(Offset(w * 0.62, h * 0.48), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(w * 0.605, h * 0.465), w * 0.022, eyeGlintPaint);

    // 6. Mũi xinh (Small cute nose)
    final nosePaint = Paint()
      ..color = const Color(0xFFFF7657)
      ..style = PaintingStyle.fill;
    final nosePath = Path()
      ..moveTo(w * 0.47, h * 0.54)
      ..lineTo(w * 0.53, h * 0.54)
      ..lineTo(w * 0.50, h * 0.575)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // 7. Nụ cười thân thiện (Smile)
    final smilePaint = Paint()
      ..color = const Color(0xFF132A13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;

    final smilePath = Path()
      ..moveTo(w * 0.44, h * 0.60)
      ..quadraticBezierTo(w * 0.50, h * 0.66, w * 0.56, h * 0.60);
    canvas.drawPath(smilePath, smilePaint);

    // 8. Má hồng (Blush)
    final blushPaint = Paint()
      ..color = const Color(0xFFFFB4A2).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.28, h * 0.55), w * 0.045, blushPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.55), w * 0.045, blushPaint);

    // 9. Bàn tay vẫy chào (nếu isWaving = true)
    if (isWaving) {
      final pawPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final pawBorder = Paint()
        ..color = const Color(0xFF086C61)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02;

      final wavePaw = Offset(w * 0.84, h * 0.50);
      canvas.drawCircle(wavePaw, w * 0.08, pawPaint);
      canvas.drawCircle(wavePaw, w * 0.08, pawBorder);

      // Tia sóng chào
      final waveRayPaint = Paint()
        ..color = const Color(0xFFFF7657)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w * 0.94, h * 0.42),
        Offset(w * 0.98, h * 0.38),
        waveRayPaint,
      );
      canvas.drawLine(
        Offset(w * 0.92, h * 0.34),
        Offset(w * 0.95, h * 0.29),
        waveRayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoAiPainter oldDelegate) {
    return oldDelegate.isWaving != isWaving;
  }
}

/// Nút GoAI nổi hình tròn (54dp) chuẩn thiết kế, có viền phát sáng nhẹ
class GoAiFloatingButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;

  const GoAiFloatingButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Hỏi Trợ lý GoAI',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppTheme.tealPrimary.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: AppTheme.mintLight,
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const GoAiMascot(size: 46),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppTheme.coralColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 9,
                    ),
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
