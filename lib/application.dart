import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
  bool _preHasVpn = false;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: commonSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        await appController.attach(currentContext, ref);
      } else {
        exit(0);
      }
      _autoUpdateProfilesTask();
      appController.initLink();
      app?.initShortcuts();
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState({required Widget child}) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(child: ProxyManager(child: child)),
        ),
      );
    }
    return AndroidManager(child: TileManager(child: child));
  }

  Widget _buildState({required Widget child}) {
    return AppStateManager(
      child: CoreManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            commonPrint.log('connectivityChanged ${results.toString()}');
            appController.updateLocalIp();
            final hasVpn = results.contains(ConnectivityResult.vpn);
            if (_preHasVpn == hasVpn) {
              appController.addCheckIp();
            }
            _preHasVpn = hasVpn;
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp({required Widget child}) {
    if (system.isDesktop) {
      return WindowHeaderContainer(child: child);
    }
    return VpnManager(child: child);
  }

  Widget _buildApp({required Widget child}) {
    return StatusManager(child: ThemeManager(child: child));
  }

  @override
  Widget build(context) {
    return Consumer(
      builder: (_, ref, child) {
        final locale = ref.watch(
          appSettingProvider.select((state) => state.locale),
        );
        final themeProps = ref.watch(themeSettingProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (_, child) {
            return AppEnvManager(
              child: _buildApp(
                child: _buildPlatformState(
                  child: _buildState(child: _buildPlatformApp(child: child!)),
                ),
              ),
            );
          },
          scrollBehavior: HiddenBarScrollBehavior(),
          title: appName,
          locale: utils.getLocaleForString(locale),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          themeMode: themeProps.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            colorScheme: _getAppColorScheme(
              brightness: Brightness.light,
              primaryColor: themeProps.primaryColor,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            colorScheme: _getAppColorScheme(
              brightness: Brightness.dark,
              primaryColor: themeProps.primaryColor,
            ).toPureBlack(themeProps.pureBlack),
          ),
          home: AppStartup(child: child!),
        );
      },
      child: const HomePage(),
    );
  }

  @override
  Future<void> dispose() async {
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    await coreController.destroy();
    await appController.handleExit();
    super.dispose();
  }
}

/// 启动遮罩：logo 优雅淡入后精确落到首页连接按钮 logo 的位置与尺寸，
/// 目标位置通过 GlobalKey 实时测量，天然适配大屏 / 小屏与底部导航、侧边栏等布局。
class AppStartup extends ConsumerStatefulWidget {
  final Widget child;

  const AppStartup({super.key, required this.child});

  @override
  ConsumerState<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<AppStartup>
    with TickerProviderStateMixin {
  bool _finished = false;
  final GlobalKey _overlayKey = GlobalKey();

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _finished = true);
      }
    })
    ..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// 读取首页 logo 锚点在遮罩坐标系中的中心与尺寸。
  ({Offset center, double size})? _readTarget() {
    final anchor = globalState.homeLogoKey.currentContext;
    final overlay = _overlayKey.currentContext;
    if (anchor == null || overlay == null) return null;
    final anchorBox = anchor.findRenderObject() as RenderBox?;
    final overlayBox = overlay.findRenderObject() as RenderBox?;
    if (anchorBox == null ||
        overlayBox == null ||
        !anchorBox.hasSize ||
        !overlayBox.hasSize) {
      return null;
    }
    final topLeft = overlayBox.globalToLocal(
      anchorBox.localToGlobal(Offset.zero),
    );
    return (center: topLeft + anchorBox.size.center(Offset.zero), size: anchorBox.size.shortestSide);
  }

  @override
  Widget build(BuildContext context) {
    final isStart = ref.watch(isStartProvider);
    final surface = context.colorScheme.surface;
    final accent = context.colorScheme.primary;
    final logoFilter = isStart
        ? null
        : ColorFilter.mode(
            context.colorScheme.onSurfaceVariant.opacity60,
            BlendMode.srcIn,
          );

    return Stack(
      children: [
        widget.child,
        if (!_finished)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _enter,
                builder: (_, __) {
                  final t = _enter.value;
                  final screenCenter = MediaQuery.sizeOf(context).center(
                    Offset.zero,
                  );
                  final target = _readTarget();
                  final targetCenter = target?.center ?? screenCenter;
                  final targetSize = target?.size ?? 68.0;

                  final appear = Curves.easeOut.transform(
                    (t / 0.2).clamp(0.0, 1.0),
                  );
                  final fly = Curves.easeInOutCubic.transform(
                    ((t - 0.22) / 0.5).clamp(0.0, 1.0),
                  );
                  final center = Offset.lerp(
                        screenCenter,
                        targetCenter,
                        fly,
                      ) ??
                      screenCenter;
                  final logoSize = 96 + (targetSize - 96) * fly;

                  final bgAlpha = (t < 0.72
                          ? 1.0
                          : (1 - t) / 0.28)
                      .clamp(0.0, 1.0)
                      .toDouble();
                  final logoAlpha = (t < 0.9 ? 1.0 : (1 - t) / 0.1)
                      .clamp(0.0, 1.0)
                      .toDouble();

                  return Stack(
                    key: _overlayKey,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: bgAlpha,
                          child: Stack(
                            children: [
                              Positioned.fill(child: ColoredBox(color: surface)),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.55,
                                      colors: [
                                        accent.withValues(alpha: 0.08),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: center.dx - logoSize / 2,
                        top: center.dy - logoSize / 2,
                        width: logoSize,
                        height: logoSize,
                        child: Opacity(
                          opacity: logoAlpha * appear,
                          child: Transform.scale(
                            scale: 1 - 0.04 * (1 - appear),
                            child: SvgPicture.asset(
                              'assets/images/phantom.svg',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.contain,
                              colorFilter: logoFilter,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}