import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PhantomHomeView extends ConsumerStatefulWidget {
  const PhantomHomeView({super.key});

  @override
  ConsumerState<PhantomHomeView> createState() => _PhantomHomeViewState();
}

class _PhantomHomeViewState extends ConsumerState<PhantomHomeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cachedTrafficProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleConnection() async {
    // 检查用户是否登录
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildProxySelector(),
                        const SizedBox(height: 24),
                        _buildConnectionButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProxySelector() {
    final mode = ref.watch(patchClashConfigProvider.select((state) => state.mode));
    return _buildModeButtons(mode);
  }

  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  Widget _buildModeButtons(Mode mode) {
    final isRule = mode == Mode.rule;
    final networkDetection = ref.watch(networkDetectionProvider);
    final ipInfo = networkDetection.ipInfo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => appController.changeMode(Mode.rule),
          child: Container(
            width: 50,
            height: 38,
            decoration: BoxDecoration(
              color: isRule ? context.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRule ? context.colorScheme.primary : context.colorScheme.outline,
              ),
            ),
            child: Center(
              child: Text(
                '规则',
                style: TextStyle(
                  color: isRule ? context.colorScheme.onPrimary : context.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: isRule ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => appController.changeMode(Mode.global),
          child: Container(
            width: 50,
            height: 38,
            decoration: BoxDecoration(
              color: !isRule ? context.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: !isRule ? context.colorScheme.primary : context.colorScheme.outline,
              ),
            ),
            child: Center(
              child: Text(
                '全局',
                style: TextStyle(
                  color: !isRule ? context.colorScheme.onPrimary : context.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: !isRule ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 50,
          height: 38,
          padding: const EdgeInsets.symmetric(),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colorScheme.outline,
            ),
          ),
          child: Center(
            child: ipInfo != null
                ? Text(
                    _countryCodeToEmoji(ipInfo.countryCode),
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: FontFamily.twEmoji.value,
                    ),
                  )
                : const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionButton() {
    return Consumer(
      builder: (_, ref, __) {
        final isStart = ref.watch(isStartProvider);
        final coreStatus = ref.watch(coreStatusProvider);
        final isConnecting = coreStatus == CoreStatus.connecting;
        
        return GestureDetector(
          onTap: isConnecting ? null : _handleConnection,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isConnecting ? 1.0 : _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isStart
                      ? [
                          Colors.greenAccent.withOpacity(0.8),
                          Colors.green.withOpacity(0.5),
                          Colors.green.withOpacity(0.2),
                        ]
                      : [
                          context.colorScheme.primary.withOpacity(0.8),
                          context.colorScheme.primary.withOpacity(0.5),
                          context.colorScheme.primary.withOpacity(0.2),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isStart ? Colors.green : context.colorScheme.primary)
                        .withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: isConnecting
                    ? SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/images/phantom.svg',
                            width: 72,
                            height: 72,
                            colorFilter: ColorFilter.mode(
                              isStart ? Colors.white : context.colorScheme.onPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isStart ? '断开' : '连接',
                            style: TextStyle(
                              color: isStart
                                  ? Colors.white
                                  : context.colorScheme.onPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}