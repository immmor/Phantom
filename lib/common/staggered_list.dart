import 'package:flutter/material.dart';

/// 错落入场卡片：子项沿主轴依次淡入并轻微上滑。
/// 仅首次挂载播放一次，父级重建不会重播。
class StaggeredCard extends StatefulWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double gap;
  final Duration duration;

  const StaggeredCard({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.gap = 8,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  Widget _item(Widget child, double begin) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, begin + 0.5, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    final children = <Widget>[];
    for (int i = 0; i < count; i++) {
      if (i > 0) children.add(SizedBox(height: widget.gap));
      children.add(_item(widget.children[i], (i / count) * 0.5));
    }
    return Column(
      mainAxisAlignment: widget.mainAxisAlignment,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: children,
    );
  }
}

/// 错落入场列表：用于设置页、工具页等，整组项依次浮现。
class StaggeredList extends StatefulWidget {
  final List<Widget> children;
  final Axis direction;
  final double gap;
  final EdgeInsetsGeometry? padding;
  final Duration duration;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const StaggeredList({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
    this.gap = 12,
    this.padding,
    this.duration = const Duration(milliseconds: 600),
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  Widget _item(Widget child, double begin) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, begin + 0.5, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    final items = <Widget>[];
    final isVertical = widget.direction == Axis.vertical;
    for (int i = 0; i < count; i++) {
      if (i > 0) {
        items.add(isVertical
            ? SizedBox(height: widget.gap)
            : SizedBox(width: widget.gap));
      }
      items.add(_item(widget.children[i], (i / count) * 0.5));
    }
    if (isVertical) {
      return ListView(
        padding: widget.padding,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        children: items,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      physics: widget.physics,
      child: Row(children: items),
    );
  }
}
