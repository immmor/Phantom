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
                _buildNoticeMarquee(),
                const SizedBox(height: 16),
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

  Widget _buildNoticeMarquee() {
    return Consumer(
      builder: (context, ref, _) {
        final messagesAsync = ref.watch(userMessagesProvider);
        
        return messagesAsync.when(
          data: (messagesData) {
            final messages = messagesData?['messages'] as List<dynamic>? ?? [];
            if (messages.isEmpty) {
              return const SizedBox.shrink();
            }
            
            final noticeText = messages.map((m) => m['content'] as String? ?? '').join('  •  ');
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_none, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        noticeText,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
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
        // Phantom 主题青色（与 phantom.svg 渐变一致）
        const cyan = Color(0xFF00F7FF);
        const cyanDeep = Color(0xFF00BDE8);
        // 已连接状态使用的暗青色（避免霓虹青过于刺眼）
        const cyanDim = Color(0xFF00838F);

        return GestureDetector(
          onTap: isConnecting ? null : _handleConnection,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外圈静态光环
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isStart ? cyan : Colors.white)
                              .withValues(alpha: isStart ? 0.85 : 0.25),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // 内圈呼吸发光环
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isConnecting ? 1.0 : _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (isStart ? cyan : cyanDeep)
                                .withValues(alpha: isStart ? 0.6 : 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isStart ? cyan : cyanDeep).withValues(
                                alpha: isStart ? 0.5 : 0.22,
                              ),
                              blurRadius: isStart ? 34 : 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 幽灵本体：未连接=暗色剪影(休眠)，已连接=原色点亮(眼睛发光)
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: isConnecting
                          ? const CircularProgressIndicator(
                              strokeWidth: 5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : SvgPicture.asset(
                              'assets/images/phantom.svg',
                              width: 96,
                              height: 96,
                              colorFilter: isStart
                                  ? null
                                  : const ColorFilter.mode(
                                      Color(0xFF9E9E9E),
                                      BlendMode.srcIn,
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  isConnecting
                      ? '连接中…'
                      : (isStart ? '已连接' : '点击连接'),
                  key: ValueKey('$isStart-$isConnecting'),
                  style: TextStyle(
                    color: isStart ? cyanDim : Colors.grey.shade400,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}