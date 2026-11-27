import 'package:flutter/material.dart';

import 'context.dart';

/// 瑞士极简背景：柔和线性渐变底 + 低饱和径向光晕 + 极淡等距网格。
/// 供首页 / 商城 / 我的页复用，统一视觉语言。
class SwissBackground extends StatelessWidget {
  /// 光晕颜色，通常取主色或连接态青色
  final Color accent;

  /// 光晕中心与范围
  final Alignment alignment;
  final double radius;
  final double glowAlpha;

  /// 网格开关
  final bool showGrid;

  const SwissBackground({
    super.key,
    required this.accent,
    this.alignment = const Alignment(-0.6, 0.55),
    this.radius = 1.15,
    this.glowAlpha = 0.1,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.colorScheme.surface;
    final outline = context.colorScheme.outline;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                accent.withValues(alpha: glowAlpha * 0.42),
                accent.withValues(alpha: glowAlpha * 0.12),
                surface,
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: alignment,
                radius: radius,
                colors: [
                  accent.withValues(alpha: glowAlpha),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        if (showGrid)
          Positioned.fill(
            child: CustomPaint(painter: _SwissGridPainter(outline)),
          ),
      ],
    );
  }
}

/// 极淡的等距网格，体现瑞士国际主义的秩序感
class _SwissGridPainter extends CustomPainter {
  final Color color;

  const _SwissGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const step = 36.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwissGridPainter old) => old.color != color;
}
