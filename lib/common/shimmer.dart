import 'package:flutter/material.dart';

/// 骨架屏微光：通过滑动渐变高亮模拟内容加载，比转圈更显高级。
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = widget.highlightColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final percent = _controller.value;
        final begin = Alignment(-1.0 + 2 * percent - 0.3, 0);
        final end = Alignment(-1.0 + 2 * percent + 0.3, 0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: begin,
            end: end,
            colors: [base, highlight, base],
          ).createShader(bounds),
          child: widget.child,
        );
      },
    );
  }
}
