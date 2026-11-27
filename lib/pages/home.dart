import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

/// 底部导航项：选中时图标坐进 accent 高亮块，无边框、无横线
class _BottomNavItem extends StatelessWidget {
  final Icon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.colorScheme.primary;
    final color = selected
        ? accent
        : context.colorScheme.onSurfaceVariant.opacity60;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon.icon, size: 21, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.4,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        child: Material(
          color: context.colorScheme.surface,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(navigationStateProvider);
              final systemUiOverlayStyle = ref.read(
                systemUiOverlayStyleStateProvider,
              );
              final isMobile = state.viewMode == ViewMode.mobile;
              final navigationItems = state.navigationItems;
              final currentIndex = state.currentIndex;
              final bottomNavigationBar = _GlassBottomNav(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < navigationItems.length; i++)
                        Expanded(
                          child: _BottomNavItem(
                            icon: navigationItems[i].icon,
                            label: Intl.message(navigationItems[i].label.name),
                            selected: i == currentIndex,
                            onTap: () => appController.toPage(
                              navigationItems[i].label,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              if (isMobile) {
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: systemUiOverlayStyle.copyWith(
                    systemNavigationBarColor:
                        context.colorScheme.surfaceContainer,
                  ),
                  child: Column(
                    children: [
                      Flexible(
                        flex: 1,
                        child: MediaQuery.removePadding(
                          removeTop: false,
                          removeBottom: true,
                          removeLeft: true,
                          removeRight: true,
                          context: context,
                          child: child!,
                        ),
                      ),
                      MediaQuery.removePadding(
                        removeTop: true,
                        removeBottom: false,
                        removeLeft: true,
                        removeRight: true,
                        context: context,
                        child: bottomNavigationBar,
                      ),
                    ],
                  ),
                );
              } else {
                return child!;
              }
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final view = KeepScope(
                      keep: navigationItem.keep,
                      child: isMobile
                          ? navigationView
                          : Navigator(
                              pages: [MaterialPage(child: navigationView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return view;
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    final pageLabel = ref.read(currentPageLabelProvider);
    if (!widget.navigationItems.any((item) => item.label == pageLabel)) {
      // 上次停留的页面已被隐藏（例如临时下线商城），回到第一个页面避免索引为 -1
      final fallback = widget.navigationItems.isNotEmpty
          ? widget.navigationItems.first.label
          : PageLabel.home;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(currentPageLabelProvider.notifier).value = fallback;
        }
      });
    }
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == ref.read(currentPageLabelProvider),
    );
    return index == -1 ? 0 : index;
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    if (!widget.navigationItems.any((item) => item.label == pageLabel)) {
      if (widget.navigationItems.isNotEmpty) {
        final fallback = widget.navigationItems.first.label;
        ref.read(currentPageLabelProvider.notifier).value = fallback;
        _toPage(fallback, true);
      }
      return;
    }
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await appController.handleBackOrExit();
        }
        return false;
      },
      child: child,
    );
  }
}

/// 底部导航栏毛玻璃层：模糊其下方内容 + 半透明底色，无分隔横线
class _GlassBottomNav extends StatelessWidget {
  final Widget child;

  const _GlassBottomNav({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHigh
                .withValues(alpha: 0.9),
          ),
          child: child,
        ),
      ),
    );
  }
}
