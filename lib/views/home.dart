import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 首页：瑞士极简排版 + 毛玻璃质感。
/// 严格网格、大留白、克制的单色点缀，功能保持与原版一致。
class PhantomHomeView extends ConsumerStatefulWidget {
  const PhantomHomeView({super.key});

  @override
  ConsumerState<PhantomHomeView> createState() => _PhantomHomeViewState();
}

class _PhantomHomeViewState extends ConsumerState<PhantomHomeView>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _pageRippleController;
  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Color? _lastAccent;
  Color? _rippleFrom;
  Color? _rippleTo;
  bool? _lastRunning;
  bool? _rippleFromRunning;
  bool? _rippleToRunning;
  bool _rippleOutward = true;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _enterController.forward();
    _pageRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 旧版本的设备级数据一次性归到当前账号
      await preferences.migrateLegacyAccountCache();
      if (!mounted) return;
      await ref.read(cachedTrafficProvider.notifier).init();
      // 补全 VIP 周期起始时间后刷新用户信息，使进度条按真实周期显示
      syncVipStartDateFromLocal().then((_) {
        if (mounted) ref.invalidate(phantomHomeProvider);
      });
      // 恢复登录后保存的每月流量配额
      await restoreMonthlyQuota();
      // 恢复当前账号的签到奖励流量
      await restoreCheckInBonus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = Theme.of(context).colorScheme.primary;
    if (_lastAccent == null) {
      _lastAccent = primary;
      _lastRunning = ref.read(isStartProvider);
      return;
    }
    if (primary != _lastAccent) {
      _rippleFrom = _lastAccent;
      _rippleTo = primary;
      _rippleFromRunning = _lastRunning;
      _rippleToRunning = ref.read(isStartProvider);
      _rippleOutward = _rippleToRunning!;
      _lastAccent = primary;
      _lastRunning = _rippleToRunning;
      _pageRippleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pageRippleController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Widget _buildPageContent({
    required bool isRunning,
    required Color accent,
    required Color outline,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isRunning, accent),
                const SizedBox(height: 16),
                _buildNoticeMarquee(accent, outline),
                _hairline(outline),
                Expanded(
                  child: Center(
                    child: _buildConnectionControl(accent),
                  ),
                ),
                _hairline(outline),
                const SizedBox(height: 18),
                _buildModeSelector(accent, outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 背景颜色揭示：上线由中心向外扩散，下线由外侧向中心收回
  Widget _buildBackgroundReveal({
    required Color fromAccent,
    required bool fromRunning,
    required Color toAccent,
    required bool toRunning,
  }) {
    return Stack(
      children: [
        SwissBackground(
          accent: fromAccent,
          glowAlpha: fromRunning ? 0.13 : 0.07,
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pageRippleController,
            builder: (context, _) {
              final t = _pageRippleController.value;
              if (t <= 0) return const SizedBox.shrink();
              final newBackground = SwissBackground(
                accent: toAccent,
                glowAlpha: toRunning ? 0.13 : 0.07,
              );
              if (t >= 1) return newBackground;
              final progress = _rippleOutward ? t : 1 - t;
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  final maxRadius = Offset(
                        bounds.width,
                        bounds.height,
                      ).distance /
                      2;
                  final reach =
                      (progress * maxRadius).clamp(0.0, maxRadius);
                  final feather = (maxRadius * 0.22).clamp(28.0, 120.0);
                  final outer = (reach / maxRadius).clamp(0.001, 1.0);
                  final inner =
                      ((reach - feather) / maxRadius).clamp(0.0, outer);
                  return RadialGradient(
                    center: Alignment.center,
                    radius: maxRadius / (bounds.shortestSide / 2),
                    colors: _rippleOutward
                        ? const [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ]
                        : const [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.white,
                          ],
                    stops: [0.0, inner, outer],
                  ).createShader(bounds);
                },
                child: newBackground,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 缓慢漂移的氛围光晕，给极简界面注入呼吸感
  Widget _buildAtmosphere(Color accent) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (_, __) {
          final phase = _ambientController.value * math.pi * 2;
          return Stack(
            children: [
              Positioned(
                left: -140 + math.sin(phase) * 26,
                top: -180 + math.cos(phase) * 20,
                child: _buildAura(380, accent.withValues(alpha: 0.06)),
              ),
              Positioned(
                right: -150 + math.cos(phase + 1.1) * 30,
                bottom: -190 + math.sin(phase + 1.1) * 24,
                child: _buildAura(440, accent.withValues(alpha: 0.045)),
              ),
              Center(
                child: _buildAura(340, accent.withValues(alpha: 0.035)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAura(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  void _handleConnection() async {
    final username = await preferences.getUsername();
    if (username == null) {
      if (mounted) {
        final res = await globalState.showMessage(
          title: '提示',
          message: const TextSpan(text: '请先登录再使用连接功能'),
          confirmText: '去登录',
        );
        if (res == true && mounted) {
          showDialog(
            context: context,
            builder: (_) => const LoginDialog(),
          );
        }
      }
      return;
    }

    final isStart = ref.read(isStartProvider);
    debouncer.call(FunctionTag.updateStatus, () {
      appController.updateStatus(!isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(isStartProvider);
    final targetAccent = context.colorScheme.primary;
    _lastAccent ??= targetAccent;
    _lastRunning ??= isRunning;
    final fromAccent = _rippleFrom ?? _lastAccent!;
    final toAccent = _rippleTo ?? targetAccent;
    final fromRunning = _rippleFromRunning ?? _lastRunning ?? isRunning;
    final toRunning = _rippleToRunning ?? isRunning;
    final outline = context.colorScheme.outline;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _pageRippleController,
        builder: (_, __) {
          final t = _pageRippleController.value;
          final accent = Color.lerp(fromAccent, toAccent, t) ?? targetAccent;
          return Stack(
            children: [
              _buildBackgroundReveal(
                fromAccent: fromAccent,
                fromRunning: fromRunning,
                toAccent: toAccent,
                toRunning: toRunning,
              ),
              _buildAtmosphere(accent),
              _buildPageContent(
                isRunning: toRunning,
                accent: accent,
                outline: outline,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 1px 分割线：瑞士风格的结构线
  Widget _hairline(Color outline) => Container(
        height: 1,
        color: outline.withValues(alpha: 0.12),
      );

  /// 顶部：编辑式品牌排版与状态徽章
  Widget _buildHeader(bool isRunning, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHANTOM',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '安全网络',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
                color: context.colorScheme.onSurfaceVariant.opacity60,
              ),
            ),
          ],
        ),
        Consumer(
          builder: (_, ref, _) {
            final isStart = ref.watch(isStartProvider);
            final coreStatus = ref.watch(coreStatusProvider);
            final isConnecting = coreStatus == CoreStatus.connecting;
            final label = isConnecting
                ? '连接中'
                : (isStart ? '已连接' : '未连接');
            final dot = isConnecting
                ? context.colorScheme.onSurfaceVariant
                : (isStart ? accent : context.colorScheme.outline);
            return GlassSurface(
              borderRadius: BorderRadius.circular(100),
              blur: 18,
              tintOpacity: 0.24,
              borderOpacity: 0.45,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              boxShadow: isStart
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.12),
                        blurRadius: 14,
                      ),
                    ]
                  : const [],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dot,
                      boxShadow: isStart
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 主连接控件：玻璃圆盘 + 中心扩散切换动画
  Widget _buildConnectionControl(Color accent) {
    return _ConnectionControl(accent: accent, onTap: _handleConnection);
  }

  /// 模式切换：带编辑式标签的轻量分段控件
  Widget _buildModeSelector(Color accent, Color outline) {
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));
    final networkDetection = ref.watch(networkDetectionProvider);
    final ipInfo = networkDetection.ipInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          borderRadius: BorderRadius.circular(18),
          blur: 18,
          tintOpacity: 0.24,
          borderOpacity: 0.45,
          boxShadow: const [],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _modeChip(
                  '直连',
                  Mode.direct,
                  mode == Mode.direct,
                  accent,
                  outline,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _modeChip(
                  '规则',
                  Mode.rule,
                  mode == Mode.rule,
                  accent,
                  outline,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _modeChip(
                  '全局',
                  Mode.global,
                  mode == Mode.global,
                  accent,
                  outline,
                ),
              ),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: outline.withValues(alpha: 0.12),
              ),
              SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: ipInfo != null
                      ? Text(
                          _countryCodeToEmoji(ipInfo.countryCode),
                          style: TextStyle(
                            fontSize: 22,
                            fontFamily: FontFamily.twEmoji.value,
                          ),
                        )
                      : SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: outline,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(
    String label,
    Mode mode,
    bool selected,
    Color accent,
    Color outline,
  ) {
    return GestureDetector(
      onTap: () => appController.changeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.35)
                : outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeMarquee(Color accent, Color outline) {
    return Consumer(
      builder: (context, ref, _) {
        final messagesAsync = ref.watch(userMessagesProvider);
        final messages = messagesAsync.value?['messages'] as List<dynamic>? ?? [];
        final noticeText = messages
            .map((m) => m['content'] as String? ?? '')
            .join('  ·  ');
        return SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    noticeText,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.78),
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) return countryCode;
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}

class _ConnectionControl extends ConsumerStatefulWidget {
  final Color accent;
  final VoidCallback onTap;

  const _ConnectionControl({
    required this.accent,
    required this.onTap,
  });

  @override
  ConsumerState<_ConnectionControl> createState() => _ConnectionControlState();
}

class _ConnectionControlState extends ConsumerState<_ConnectionControl>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final AnimationController _rippleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _playRipple() {
    if (mounted) _rippleController.forward(from: 0);
  }

  Widget _buildRipple() {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (_, __) {
        final t = _rippleController.value;
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        return Container(
          width: 208 * t,
          height: 208 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.accent.withValues(alpha: 0.22 * (1 - t)),
                widget.accent.withValues(alpha: 0.08 * (1 - t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHalo() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.22, end: 0.55).animate(_pulseController),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.86, end: 1).animate(_pulseController),
        child: Container(
          width: 196,
          height: 196,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.accent.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isStartProvider, (_, __) => _playRipple());
    ref.listen(coreStatusProvider, (_, __) => _playRipple());
    final isStart = ref.watch(isStartProvider);
    final coreStatus = ref.watch(coreStatusProvider);
    final isConnecting = coreStatus == CoreStatus.connecting;
    final accent = widget.accent;

    return GestureDetector(
      onTap: isConnecting ? null : widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isStart ? 1.01 : (isConnecting ? 1.005 : 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          width: 208,
          height: 208,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isStart
                    ? accent.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isStart ? 44 : 24,
                spreadRadius: isStart ? 2 : 0,
              ),
            ],
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(104),
            blur: 24,
            tintOpacity: 0.24,
            borderOpacity: 0.5,
            boxShadow: const [],
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildHalo(),
                  _buildRipple(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 520),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(
                          alpha: isStart ? 0.34 : 0.1,
                        ),
                        width: isStart ? 1.2 : 0.8,
                      ),
                    ),
                  ),
                  KeyedSubtree(
                    key: globalState.homeLogoKey,
                    child: const SizedBox(width: 68, height: 68),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.92, end: 1).animate(
                            animation,
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: isConnecting
                        ? SizedBox(
                            key: const ValueKey('connecting'),
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accent,
                              ),
                            ),
                          )
                        : SvgPicture.asset(
                            key: ValueKey(isStart ? 'connected' : 'idle'),
                            'assets/images/phantom.svg',
                            width: 68,
                            height: 68,
                            colorFilter: isStart
                                ? null
                                : ColorFilter.mode(
                                    context.colorScheme.onSurfaceVariant
                                        .opacity60,
                                    BlendMode.srcIn,
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
