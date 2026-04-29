import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

final _phantomHomeProvider = FutureProvider<PhantomUserInfo?>((ref) async {
  final username = await preferences.getUsername();
  if (username == null) return null;

  final expireDateStr = await preferences.getVExpireDate();
  final balance = await preferences.getBalance();

  DateTime? expireDate;
  if (expireDateStr != null) {
    expireDate = DateTime.tryParse(expireDateStr);
  }

  return PhantomUserInfo(
    username: username,
    balance: balance,
    expireDate: expireDate,
  );
});

Future<String?> _renewVip(int duration) async {
  final username = await preferences.getUsername();
  if (username == null) return '用户未登录';
  try {
    final dio = Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) => 'DIRECT';
          client.badCertificateCallback = (_, host, cert) => true;
          return client;
        },
      );
    final price = duration == 365 ? 450.0 : 40.0;
    final res = await dio.post(
      'https://api.immmor.com/api/open-vip',
      data: {'username': username, 'duration': duration, 'price': price},
    );
    if (res.data['code'] == 200) {
      final data = res.data['data'];
      await preferences.setBalance(data['balance']);
      await preferences.setVExpireDate(data['v_expire_date']);
      await preferences.setVToken(data['v_token']);
      return null;
    }
    return res.data['msg'] ?? '续费失败';
  } catch (e) {
    return '网络错误';
  }
}

class _RenewButton extends ConsumerWidget {
  final int duration;
  final double price;
  final bool isVip;

  const _RenewButton({required this.duration, required this.price, required this.isVip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认续费'),
            content: Text('确定要${isVip ? '续费' : '开通'} VIP 吗？\n${duration == 365 ? '年付' : '月付'}：¥$price'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          final msg = await _renewVip(duration);
          if (msg == null && context.mounted) {
            ref.invalidate(_phantomHomeProvider);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isVip ? '续费成功' : '开通成功')));
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? '续费失败')));
          }
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: isVip ? Colors.green : Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14), minimumSize: const Size(0, 44)),
      child: Text('${duration == 365 ? '年付' : '月付'} ¥$price', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _CachedTraffic {
  double up;
  double down;

  _CachedTraffic({this.up = 0, this.down = 0});
}

final _cachedTrafficProvider =
    NotifierProvider<_CachedTrafficNotifier, _CachedTraffic>(
  _CachedTrafficNotifier.new,
);

class _CachedTrafficNotifier extends Notifier<_CachedTraffic> {
  @override
  _CachedTraffic build() {
    return _CachedTraffic();
  }

  Future<void> init() async {
    final cachedUp = await preferences.getCachedTotalUpTraffic() ?? 0;
    final cachedDown = await preferences.getCachedTotalDownTraffic() ?? 0;
    state = _CachedTraffic(up: cachedUp, down: cachedDown);
  }

  Future<void> addTraffic(Traffic traffic) async {
    final newUp = state.up + traffic.up;
    final newDown = state.down + traffic.down;
    await preferences.setCachedTotalUpTraffic(newUp);
    await preferences.setCachedTotalDownTraffic(newDown);
    state = _CachedTraffic(up: newUp, down: newDown);
  }
}

class PhantomUserInfo {
  final String username;
  final double? balance;
  final DateTime? expireDate;

  PhantomUserInfo({
    required this.username,
    this.balance,
    this.expireDate,
  });

  bool get isVip => expireDate != null && expireDate!.isAfter(DateTime.now());

  String get expireDateShow => expireDate?.show ?? appLocalizations.infiniteTime;

  Duration get remainingDuration {
    if (expireDate == null) return Duration.zero;
    final diff = expireDate!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int get totalDays => 30;

  double get expireProgress {
    if (!isVip) return 0.0;
    final totalSeconds = totalDays * 24 * 60 * 60;
    final remainingSeconds = remainingDuration.inSeconds;
    if (totalSeconds <= 0) return 0.0;
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }
}

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
      ref.read(_cachedTrafficProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleConnection() {
    final isStart = ref.read(isStartProvider);
    debouncer.call(FunctionTag.updateStatus, () {
      appController.updateStatus(!isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final userInfoAsync = ref.watch(_phantomHomeProvider);

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
                const SizedBox(height: 10),
                userInfoAsync.when(
                  data: (userInfo) {
                    if (userInfo == null) return _buildNotLoggedIn();
                    return _buildUserInfo(userInfo);
                  },
                  loading: () => const _LoadingIndicator(),
                  error: (_, __) => _buildNotLoggedIn(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProxySelector(),
                      const SizedBox(height: 24),
                      _buildConnectionButton(),
                    ],
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

  Widget _buildNotLoggedIn() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 64,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '未登录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(PhantomUserInfo userInfo) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: userInfo.isVip
                  ? [
                      Colors.green.withOpacity(0.2),
                      Colors.green.withOpacity(0.05),
                    ]
                  : [
                      Colors.grey.withOpacity(0.2),
                      Colors.grey.withOpacity(0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: userInfo.isVip
                  ? Colors.green.withOpacity(0.3)
                  : context.colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (userInfo.isVip ? Colors.green : Colors.grey).withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    userInfo.username,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showVipBottomSheet(context, userInfo),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: userInfo.isVip ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.diamond,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userInfo.isVip ? 'VIP' : '普通',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTrafficRow(userInfo),
              const SizedBox(height: 8),
              _buildVipCountdownRow(userInfo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficRow(PhantomUserInfo userInfo) {
    final cachedTraffic = ref.watch(_cachedTrafficProvider);
    final currentTraffic = ref.watch(totalTrafficProvider);

    ref.listen(totalTrafficProvider, (previous, next) {
      if (previous == null || (previous.up == 0 && previous.down == 0)) return;
      ref.read(_cachedTrafficProvider.notifier).addTraffic(next);
    });

    final totalBytes = cachedTraffic.up + cachedTraffic.down + currentTraffic.up + currentTraffic.down;
    const maxBytes = 2 * 1024 * 1024 * 1024;
    final progress = (totalBytes / maxBytes).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.data_saver_off, color: Colors.blue, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '流量使用',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalBytes.traffic.show} / ${maxBytes.traffic.show} (${(progress * 100).toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildRenewalButton(userInfo),
      ],
    );
  }

  Widget _buildRenewalButton(PhantomUserInfo userInfo) {
    return GestureDetector(
      onTap: () => _showVipBottomSheet(context, userInfo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '续费',
          style: TextStyle(
            color: context.colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showVipBottomSheet(BuildContext context, PhantomUserInfo userInfo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final userInfoAsync = ref.watch(_phantomHomeProvider);
          return userInfoAsync.when(
            data: (updatedUserInfo) {
              final info = updatedUserInfo ?? userInfo;
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          info.isVip ? Icons.diamond : Icons.diamond_outlined,
                          color: info.isVip ? Colors.green : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          info.isVip ? 'VIP 会员' : '普通用户',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: info.isVip ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (info.balance != null)
                      Text(
                        '余额: ¥${info.balance!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: info.isVip ? Colors.green.shade700 : Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _RenewButton(duration: 30, price: 40, isVip: info.isVip),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RenewButton(duration: 365, price: 450, isVip: info.isVip),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildVipCountdownRow(PhantomUserInfo userInfo) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final remaining = userInfo.remainingDuration;
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        final minutes = remaining.inMinutes % 60;
        final seconds = remaining.inSeconds % 60;
        return Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.timer, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIP 剩余',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: userInfo.expireProgress,
                      minHeight: 8,
                      backgroundColor: Colors.green.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${days}天 ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildRenewalButton(userInfo),
          ],
        );
      },
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

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          context.colorScheme.primary,
        ),
      ),
    );
  }
}