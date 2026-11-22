import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 点击缩放微交互：按下时轻微缩小，回弹放大。
/// 统一用于卡片、按钮与列表项，配合可选触感反馈，提升操作质感。
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool enableFeedback;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.95,
    this.enableFeedback = false,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0,
    upperBound: 1,
  )..value = 1;

  void _pressDown(TapDownDetails _) {
    if (widget.enableFeedback) HapticFeedback.lightImpact();
    _controller.animateTo(0);
  }

  void _pressUp(TapUpDetails _) => _controller.animateTo(1);

  void _pressCancel() => _controller.animateTo(1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _controller.drive(
      Tween<double>(begin: widget.pressedScale, end: 1),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : _pressDown,
      onTapUp: widget.onTap == null ? null : _pressUp,
      onTapCancel: widget.onTap == null ? null : _pressCancel,
      onTap: widget.onTap,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}
