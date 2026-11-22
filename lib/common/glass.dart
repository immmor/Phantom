import 'dart:ui';

import 'package:flutter/material.dart';

/// 玻璃拟态容器：毛玻璃模糊 + 半透明底色 + 细描边 + 柔光阴影。
/// 用于侧边栏、底部导航栏、弹窗与卡片，营造统一的高级质感。
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? tint;
  final double tintOpacity;
  final double borderOpacity;
  final List<BoxShadow>? boxShadow;
  final bool clip;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 20,
    this.tint,
    this.tintOpacity = 0.55,
    this.borderOpacity = 0.5,
    this.boxShadow,
    this.clip = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    final surface = tint ?? Theme.of(context).colorScheme.surfaceContainer;
    final outline = Theme.of(context).colorScheme.outline;
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface.withOpacity(tintOpacity),
        borderRadius: radius,
        border: Border.all(
          color: outline.withOpacity(borderOpacity * 0.35),
          width: 1,
        ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: child,
    );
    final filtered = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: inner,
    );
    return clip ? ClipRRect(borderRadius: radius, child: filtered) : filtered;
  }
}
