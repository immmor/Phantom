import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_clash/l10n/l10n.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.a && next.c) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        appController.savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        appController.updateGroupsDebounce();
      }
    });
    if (window == null) {
      return;
    }
    ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
      if (prev == next) {
        return;
      }
      if (next.a == true && next.b == true) {
        macOS?.updateDns(false);
      } else {
        macOS?.updateDns(true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      render?.resume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appController.tryCheckIp();
        if (system.isAndroid) {
          appController.tryStartCore();
        }
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    appController.updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  // Widget _buildLoading() {
  //   return Consumer(
  //     builder: (_, ref, _) {
  //       final loading = ref.watch(loadingProvider);
  //       final isMobileView = ref.watch(isMobileViewProvider);
  //       return loading && !isMobileView
  //           ? RotatedBox(
  //               quarterTurns: 1,
  //               child: const LinearProgressIndicator(),
  //             )
  //           : Container();
  //     },
  //   );
  // }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    return GlassSurface(
      tint: context.colorScheme.surfaceContainerHigh,
      tintOpacity: 0.9,
      blur: 20,
      borderRadius: BorderRadius.zero,
      borderOpacity: 0,
      boxShadow: const [],
      clip: false,
      child: child,
    );
  }

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  String getPageLabelName(PageLabel label) {
    return switch (label) {
      PageLabel.home => AppLocalizations.current.home,
      PageLabel.dashboard => AppLocalizations.current.dashboard,
      PageLabel.proxies => AppLocalizations.current.proxies,
      PageLabel.profiles => AppLocalizations.current.profiles,
      PageLabel.tools => AppLocalizations.current.tools,
      PageLabel.logs => AppLocalizations.current.logs,
      PageLabel.requests => AppLocalizations.current.requests,
      PageLabel.resources => AppLocalizations.current.resources,
      PageLabel.connections => AppLocalizations.current.connections,
      PageLabel.mine => AppLocalizations.current.mine,
      PageLabel.mall => '商城',
    };
  }

  /// 自定义导航项：仅图标 + 文字，无高亮块、无边框、无横线
  Widget _buildSidebarNavItem({
    required BuildContext context,
    required NavigationItem item,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = context.colorScheme.primary;
    final color = selected
        ? accent
        : context.colorScheme.onSurfaceVariant.opacity60;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon.icon, size: 21, color: color),
            const SizedBox(height: 4),
            Text(
              getPageLabelName(item.label),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
                decorationThickness: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 侧边栏品牌头：直接使用连接状态下的原色 logo
  Widget _buildSidebarBrand(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SvgPicture.asset(
        'assets/images/phantom.svg',
        width: 34,
        height: 34,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: _buildBackground(
            context: context,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (system.isMacOS) const SizedBox(height: 22),
                  const SizedBox(height: 10),
                  if (!system.isMacOS) ...[
                    const ClipRect(child: AppIcon()),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: HiddenBarScrollBehavior(),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < navigationItems.length; i++)
                              _buildSidebarNavItem(
                                context: context,
                                item: navigationItems[i],
                                selected: i == currentIndex,
                                onTap: () => appController.toPage(
                                  navigationItems[i].label,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSidebarBrand(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (_, constraints) {
                _updateSideBarWidth(ref, constraints.maxWidth);
                return child;
              },
            ),
          ),
        ),
      ],
    );
  }
}
