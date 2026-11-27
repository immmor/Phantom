import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/webview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

final checkInBonusTraffic = ValueNotifier<double>(0.0);

/// 未取到后端配额时的兜底值（2GB）
const defaultMonthlyQuotaBytes = 2 * 1024 * 1024 * 1024.0;

/// 每月基础配额（字节），登录后由后端 monthly_quota(MB) 换算写入
final monthlyQuotaBytes = ValueNotifier<double>(defaultMonthlyQuotaBytes);

/// 把后端 monthly_quota（MB，可为空）写入本地并同步全局配额值
Future<void> applyMonthlyQuota(num? quotaMb) async {
  final mb = quotaMb?.toDouble();
  await preferences.setMonthlyQuota(mb);
  monthlyQuotaBytes.value = mb == null ? defaultMonthlyQuotaBytes : mb * 1024 * 1024;
}

/// App 启动时从本地恢复配额
Future<void> restoreMonthlyQuota() async {
  await applyMonthlyQuota(await preferences.getMonthlyQuota());
}

/// App 启动时恢复当前账号的签到奖励流量。
Future<void> restoreCheckInBonus() async {
  checkInBonusTraffic.value = await preferences.getCheckInBonusTraffic() ?? 0;
}

/// 切换账号后重新加载该账号自己的本地数据（签到状态、已用流量、签到奖励）。
/// 数据不会被清空，只是换成当前账号的那一份。
Future<void> reloadAccountScopedCache(ProviderContainer container) async {
  // 旧设备级数据先归到当前账号，再读取
  await preferences.migrateLegacyAccountCache();
  await restoreCheckInBonus();
  container.invalidate(lastCheckInDateProvider);
  // 直接在原 notifier 上重新读取，避免 invalidate 后 init() 被
  // _initialized 短路而显示成 0。
  await container.read(cachedTrafficProvider.notifier).reload();
}

/// 登录 / 切换账号时下载订阅。
/// 强制走 DIRECT：此时还没有可用的新节点，走旧核心代理会失败。
Future<Profile?> addProfileDirect(
  ProviderContainer container,
  String url,
  String label, {
  bool autoSelect = true,
}) async {
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

    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    var profile = Profile.normal(label: label, url: url).copyWith(
      subscriptionInfo: SubscriptionInfo.formHString(
        response.headers.value('subscription-userinfo'),
      ),
    );
    profile = await profile.saveFile(response.data ?? Uint8List(0));

    container.read(profilesProvider.notifier).put(profile);
    if (autoSelect) {
      container.read(currentProfileIdProvider.notifier).value = profile.id;
    }
    return profile;
  } catch (e) {
    debugPrint('添加订阅失败：$e');
    return null;
  }
}

/// 高级感配色：VIP 采用香槟金，普通用户采用中性灰，整体在浅色主题下保持克制。
const Color _gold = Color(0xFFD4AF37);
const Color _goldDark = Color(0xFFB8860B);

final phantomHomeProvider = FutureProvider<PhantomUserInfo?>((ref) async {
  final username = await preferences.getUsername();
  if (username == null) return null;

  final expireDateStr = await preferences.getVExpireDate();
  final balance = await preferences.getBalance();

  DateTime? expireDate;
  if (expireDateStr != null) {
    expireDate = DateTime.tryParse(expireDateStr);
  }

  final startDate = await syncVipStartDate(expireDate);

  return PhantomUserInfo(
    username: username,
    balance: balance,
    expireDate: expireDate,
    startDate: startDate,
  );
});

final userMessagesProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final username = await preferences.getUsername();
  if (username == null) return null;

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

    final res = await dio.get(
      'https://api.immmor.com/api/messages',
      queryParameters: {'username': username},
    );

    if (res.data['code'] == 200) {
      return res.data['data'];
    }
    return null;
  } catch (e) {
    debugPrint('获取消息失败：$e');
    return null;
  }
});

final lastCheckInDateProvider = FutureProvider<DateTime?>((ref) async {
  return await preferences.getLastCheckInDate();
});

/// 获取指定时长的 VIP 价格（优先读取本地价格计划，失败时使用默认值）
Future<double> getVipPrice(int duration) async {
  final pricePlan = await preferences.getPricePlan();
  if (duration == 365) {
    return (pricePlan?['annual_discount'] as num?)?.toDouble() ?? 350.0;
  }
  return (pricePlan?['monthly_discount'] as num?)?.toDouble() ?? 30.0;
}

/// 同步 VIP 权益起始时间（登录 / App 启动时调用）。
/// 本地无记录时（旧版本升级、跨设备登录）以当前时间作为起点并持久化，
/// 之后到期时间因叠加续费而后移，已购总时长自然累加。
Future<DateTime?> syncVipStartDate(DateTime? expireDate) async {
  if (expireDate == null) {
    await preferences.setVipStartDate(null);
    return null;
  }
  final savedStr = await preferences.getVipStartDate();
  final saved = savedStr == null ? null : DateTime.tryParse(savedStr);
  if (saved != null && saved.isBefore(expireDate)) return saved;
  // 无记录或记录异常（不早于到期时间），以当前时间作为起点
  final now = DateTime.now();
  await preferences.setVipStartDate(now.toIso8601String());
  return now;
}

/// 续费成功后维护权益起始时间：
/// 叠加续费（原 VIP 仍有效）时保持起点不变，已购总时长随到期时间延长而累加；
/// 首次开通或过期后重新开通时，重置起点为当前时间。
Future<void> markVipRenewed(DateTime? newExpireDate, bool wasVip) async {
  if (newExpireDate == null) return;
  if (wasVip) return;
  await preferences.setVipStartDate(DateTime.now().toIso8601String());
}

/// 从本地缓存读取到期时间并同步权益起始时间
Future<void> syncVipStartDateFromLocal() async {
  final expireDateStr = await preferences.getVExpireDate();
  await syncVipStartDate(
    expireDateStr == null ? null : DateTime.tryParse(expireDateStr),
  );
}

Future<String?> renewVip(int duration) async {
  final username = await preferences.getUsername();
  if (username == null) return '用户未登录';
  // 记录续费前的 VIP 状态，用于区分「叠加续费」与「新开 / 过期重开」
  final oldExpireStr = await preferences.getVExpireDate();
  final oldExpire =
      oldExpireStr == null ? null : DateTime.tryParse(oldExpireStr);
  final wasVip = oldExpire != null && oldExpire.isAfter(DateTime.now());
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
    final price = await getVipPrice(duration);
    final res = await dio.put(
      'https://api.immmor.com/api/open-vip',
      data: {'username': username, 'duration': duration, 'price': price},
    );
    if (res.data['code'] == 200) {
      final data = res.data['data'];
      await preferences.setBalance((data['balance'] as num?)?.toDouble());
      await preferences.setVExpireDate(data['v_expire_date']);
      await preferences.setVToken(data['v_token']);
      await markVipRenewed(
        DateTime.tryParse(data['v_expire_date']?.toString() ?? ''),
        wasVip,
      );
      return null;
    }
    return res.data['msg'] ?? '续费失败';
  } catch (e) {
    return '网络错误';
  }
}

/// 从服务器静默刷新余额（失败时保留本地缓存值）
Future<void> refreshUserBalance(WidgetRef ref) async {
  final username = await preferences.getUsername();
  if (username == null) return;
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
    final res = await dio.get(
      'https://api.immmor.com/api/balance',
      queryParameters: {'username': username},
    );
    if (res.data['code'] == 200) {
      final balance = (res.data['balance'] as num?)?.toDouble();
      await preferences.setBalance(balance);
      ref.invalidate(phantomHomeProvider);
    }
  } catch (e) {
    debugPrint('刷新余额失败：$e');
  }
}

/// 打开充值页面：先生成一次性免密授权码，让充值页自动登录，
/// Android / iOS / macOS 使用应用内 WebView，其余平台回退外部浏览器。
Future<void> openPayPage(BuildContext context) async {
  const basePayUrl = 'https://funbua.uk/vpay';
  var payUrl = basePayUrl;
  final username = await preferences.getUsername();
  if (username != null) {
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
      final res = await dio.post(
        'https://api.immmor.com/api/quick-login-ticket',
        data: {'username': username},
        options: Options(headers: {'Origin': 'https://phantom.immmor.com'}),
      );
      if (res.data['success'] == true && res.data['ticket'] != null) {
        payUrl =
            '$basePayUrl?ticket=${Uri.encodeComponent(res.data['ticket'] as String)}';
      }
    } catch (e) {
      debugPrint('获取充值授权码失败：$e');
    }
  }
  if (!context.mounted) return;
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InAppWebViewPage(url: payUrl, title: '充值'),
      ),
    );
    return;
  }
  launchUrl(Uri.parse(payUrl));
}

class RenewButton extends ConsumerWidget {
  final int duration;
  final bool isVip;

  const RenewButton({super.key, required this.duration, required this.isVip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double>(
      future: getVipPrice(duration),
      builder: (context, snapshot) {
        final price = snapshot.data ?? (duration == 365 ? 350.0 : 30.0);
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
              final msg = await renewVip(duration);
              if (context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                if (msg == null) {
                  ref.invalidate(phantomHomeProvider);
                }
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      msg == null
                          ? (isVip ? '续费成功' : '开通成功')
                          : (msg ?? '续费失败'),
                    ),
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: isVip ? Colors.green : Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14), minimumSize: const Size(0, 44)),
          child: Text('${duration == 365 ? '年付' : '月付'} ¥$price', style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }
}

class CachedTraffic {
  double up;
  double down;

  CachedTraffic({this.up = 0, this.down = 0});
}

final cachedTrafficProvider =
    NotifierProvider<CachedTrafficNotifier, CachedTraffic>(
  CachedTrafficNotifier.new,
);

class CachedTrafficNotifier extends Notifier<CachedTraffic> {
  bool _initialized = false;

  @override
  CachedTraffic build() {
    return CachedTraffic();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final cachedUp = await preferences.getCachedTotalUpTraffic() ?? 0;
    final cachedDown = await preferences.getCachedTotalDownTraffic() ?? 0;
    debugPrint(
      'cached traffic loaded: user=${await preferences.getUsername()} '
      'up=$cachedUp down=$cachedDown',
    );
    state = CachedTraffic(up: cachedUp, down: cachedDown);
  }

  /// 账号切换后强制重新读取当前账号的流量缓存。
  Future<void> reload() async {
    _initialized = false;
    await init();
  }

  Future<void> addTraffic(Traffic traffic) async {
    await init();
    final newUp = state.up + traffic.up;
    final newDown = state.down + traffic.down;
    await preferences.setCachedTotalUpTraffic(newUp);
    await preferences.setCachedTotalDownTraffic(newDown);
    state = CachedTraffic(up: newUp, down: newDown);
  }
}

class PhantomUserInfo {
  final String username;
  final double? balance;
  final DateTime? expireDate;
  final DateTime? startDate;

  PhantomUserInfo({
    required this.username,
    this.balance,
    this.expireDate,
    this.startDate,
  });

  bool get isVip => expireDate != null && expireDate!.isAfter(DateTime.now());

  String get expireDateShow => expireDate?.show ?? appLocalizations.infiniteTime;

  Duration get remainingDuration {
    if (expireDate == null) return Duration.zero;
    final diff = expireDate!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// 已购 VIP 总时长 = 到期时间 − 权益起始时间。
  /// 多次叠加续费时，到期时间后移，总时长自然累加。
  Duration get totalDuration {
    final start = startDate;
    final expire = expireDate;
    if (start == null || expire == null) return remainingDuration;
    final diff = expire.difference(start);
    return diff.isNegative ? remainingDuration : diff;
  }

  double get expireProgress {
    if (!isVip) return 0.0;
    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds <= 0) return 0.0;
    final remainingSeconds = remainingDuration.inSeconds;
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }
}

class UserCardWidget extends ConsumerWidget {
  const UserCardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfoAsync = ref.watch(phantomHomeProvider);

    return userInfoAsync.when(
      data: (userInfo) {
        if (userInfo == null) return _buildNotLoggedIn(context);
        return _buildUserInfo(context, ref, userInfo);
      },
      loading: () => const _LoadingIndicator(),
      error: (_, __) => _buildNotLoggedIn(context),
      skipLoadingOnRefresh: true,
    );
  }

  static Widget _buildNotLoggedIn(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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

  static Widget _buildUserInfo(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    return ValueListenableBuilder<double>(
      valueListenable: checkInBonusTraffic,
      builder: (context, bonus, child) {
        final lastCheckInDateAsync = ref.watch(lastCheckInDateProvider);
        final DateTime? lastCheckInDate = lastCheckInDateAsync.value;
        final isTodayChecked = lastCheckInDate != null && _isToday(lastCheckInDate);
        
        return Column(
          children: [
            SizedBox(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colorScheme.surfaceContainerHighest,
                      context.colorScheme.surfaceContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.colorScheme.outline.withOpacity(0.18),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: StaggeredCard(
                  mainAxisAlignment: MainAxisAlignment.center,
                  gap: 14,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(context),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatUsername(userInfo.username),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                    ),
                                  ),
                                  TapScale(
                                    onTap: () =>
                                        _showVipBottomSheet(context, ref, userInfo),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 450),
                                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: userInfo.isVip
                                            ? const LinearGradient(
                                                colors: [_gold, _goldDark],
                                              )
                                            : null,
                                        color: userInfo.isVip
                                            ? null
                                            : context
                                                .colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(20),
                                        border: userInfo.isVip
                                            ? null
                                            : Border.all(
                                                color: context
                                                    .colorScheme.outline
                                                    .withOpacity(0.3),
                                              ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.diamond,
                                            color: userInfo.isVip
                                                ? Colors.white
                                                : context.colorScheme
                                                    .onSurfaceVariant,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            userInfo.isVip ? 'VIP' : '普通',
                                            style: TextStyle(
                                              color: userInfo.isVip
                                                  ? Colors.white
                                                  : context.colorScheme
                                                      .onSurfaceVariant,
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
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildMessageButton(context, ref),
                                  const SizedBox(width: 8),
                                  _buildCheckInButton(context, ref, isTodayChecked),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildTrafficRow(context, ref, userInfo),
                    _buildVipCountdownRow(context, ref, userInfo),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static String _formatUsername(String username) {
    if (username.length <= 6) {
      return username;
    }
    return username.substring(0, 6) + '*';
  }

  /// 头像：仅 logo，无外圈。
  static Widget _buildAvatar(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/phantom.svg',
          width: 40,
          height: 40,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurfaceVariant.opacity60,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  static Widget _buildCheckInButton(BuildContext context, WidgetRef ref, bool isTodayChecked) {
    return TapScale(
      // 始终允许点击：本地日期可能被旧版本写入但服务端并未签到，
      // 让服务端判定是否重复，同时可顺带刷新已过期的免费节点。
      onTap: () => _handleCheckIn(context, ref),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isTodayChecked ? Colors.grey : Colors.orange,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTodayChecked ? Icons.check_circle : Icons.calendar_today,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              isTodayChecked ? '已签到' : '签到',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _handleCheckIn(BuildContext context, WidgetRef ref) async {
    final username = await preferences.getUsername();
    if (username == null || username.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
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

      final res = await dio.post(
        'https://api.immmor.com/api/checkin',
        data: {
          'username': username,
          // 与 JS Date#getTimezoneOffset 一致：UTC - 本地（东八区为 -480）
          'timezoneOffset': -DateTime.now().timeZoneOffset.inMinutes,
        },
      );

      final data = res.data;
      final code = data is Map ? data['code'] : null;
      if (code != 200) {
        final msg =
            (data is Map ? data['msg'] : null)?.toString() ?? '签到失败，请稍后重试';
        messenger.showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      final msg =
          (data is Map ? data['msg'] : null)?.toString() ?? '签到成功，免费节点已更新';

      await preferences.setLastCheckInDate(DateTime.now());
      ref.invalidate(lastCheckInDateProvider);

      // 服务端返回「今日已签到」时不重复发放本地奖励
      if (!msg.contains('已签到')) {
        checkInBonusTraffic.value += 50 * 1024 * 1024;
        await preferences.setCheckInBonusTraffic(checkInBonusTraffic.value);
      }

      // 免费节点有效期由后端签到结果决定，签到后需重新下载订阅才会生效
      await _refreshFreeProfile(ref);

      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('签到失败：$e');
      messenger.showSnackBar(
        const SnackBar(content: Text('签到失败，请检查网络后重试')),
      );
    }
  }

  /// 重新下载并应用免费节点订阅，让签到后的节点立即生效。
  static Future<void> _refreshFreeProfile(WidgetRef ref) async {
    final freeProfiles = ref
        .read(profilesProvider)
        .where((p) => p.url.contains('/free/clash') || p.label.contains('免费'))
        .toList();
    for (final profile in freeProfiles) {
      try {
        await appController.updateProfile(profile);
      } catch (e) {
        debugPrint('刷新免费节点失败：$e');
      }
    }
  }

  static Widget _buildMessageButton(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(userMessagesProvider);
    
    return messagesAsync.when(
      data: (messagesData) {
        final unreadCount = messagesData?['unreadCount'] ?? 0;
        final hasUnread = unreadCount > 0;
        
        return TapScale(
          onTap: () async {
            // 点击时刷新消息数据
            await ref.refresh(userMessagesProvider);
            if (context.mounted) {
              _showMessagesBottomSheet(context, ref);
            }
          },
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: hasUnread ? Colors.orange : Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.message_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static void _showMessagesBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final messagesAsync = ref.watch(userMessagesProvider);
          return messagesAsync.when(
            data: (messagesData) {
              final messages = messagesData?['messages'] as List<dynamic>? ?? [];
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
                        Icon(Icons.message, color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          '消息通知',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('暂无消息'),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: messages.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, index) {
                            final msg = messages[index];
                            final content = msg['content'] as String? ?? '';
                            final createdAt = msg['created_at'] as String? ?? '';
                            
                            // 转换为北京时间 (UTC+8)
                            String displayTime = createdAt;
                            if (createdAt.isNotEmpty) {
                              try {
                                final utcTime = DateTime.parse(createdAt);
                                final beijingTime = utcTime.add(const Duration(hours: 8));
                                displayTime = beijingTime.toString().substring(0, 19);
                              } catch (e) {
                                // 解析失败时显示原始时间
                              }
                            }
                            
                            return ListTile(
                              title: Text(content),
                              subtitle: Text(displayTime),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('加载失败：$e')),
          );
        },
      ),
    );
  }

  static Widget _buildTrafficRow(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    return ValueListenableBuilder<double>(
      valueListenable: monthlyQuotaBytes,
      builder: (context, baseMaxBytes, child) => Consumer(
      builder: (context, ref, child) {
        // 流量增量累加与限额判断已移到 controller.updateTraffic 数据层，
        // 这里只做展示，避免卡片未挂载时流量漏记
        final cachedTraffic = ref.watch(cachedTrafficProvider);
        final usedBytes = cachedTraffic.up + cachedTraffic.down;
        final maxBytes = baseMaxBytes + checkInBonusTraffic.value; // 总配额 = 后端月配额 + 签到奖励
        final progress = maxBytes > 0 ? (usedBytes / maxBytes).clamp(0.0, 1.0) : 0.0;
        return Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.25),
                    Colors.indigo.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.data_saver_off, color: Colors.blue.shade700, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '流量',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_upward,
                          size: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          cachedTraffic.up.traffic.show,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_downward,
                          size: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          cachedTraffic.down.traffic.show,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
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
                      '${usedBytes.traffic.show} / ${maxBytes.traffic.show} (${(progress * 100).toStringAsFixed(1)}%)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildRenewalButton(context, ref, userInfo),
          ],
        );
      },
      ),
    );
  }

  static Widget _buildRenewalButton(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    return TapScale(
      onTap: () => _showVipBottomSheet(context, ref, userInfo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: userInfo.isVip
              ? const LinearGradient(colors: [_gold, _goldDark])
              : null,
          color: userInfo.isVip ? null : context.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '续费',
          style: TextStyle(
            color: userInfo.isVip ? Colors.white : context.colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static void _showVipBottomSheet(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    // 打开弹窗时静默刷新余额，成功后弹窗内会自动显示新值
    refreshUserBalance(ref);
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final userInfoAsync = ref.watch(phantomHomeProvider);
          return userInfoAsync.when(
            data: (updatedUserInfo) {
              final info = updatedUserInfo ?? userInfo;
              return Container(
                key: ValueKey(info.isVip),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '余额: ¥${info.balance!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: info.isVip ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => openPayPage(context),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flash_on, size: 14, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text(
                                    '充值',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: RenewButton(duration: 30, isVip: info.isVip),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RenewButton(duration: 365, isVip: info.isVip),
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

  static Widget _buildVipCountdownRow(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    return _VipCountdown(userInfo: userInfo);
  }
}

/// VIP 倒计时：stream 只在 initState 创建一次，避免每次重建都新建
/// Stream.periodic 导致同一流被重复 listen（"Stream has already been listened to"）。
class _VipCountdown extends ConsumerStatefulWidget {
  final PhantomUserInfo userInfo;

  const _VipCountdown({required this.userInfo});

  @override
  ConsumerState<_VipCountdown> createState() => _VipCountdownState();
}

class _VipCountdownState extends ConsumerState<_VipCountdown> {
  late final Stream<void> _tick =
      Stream.periodic(const Duration(seconds: 1)).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    final userInfo = widget.userInfo;
    return StreamBuilder<void>(
      stream: _tick,
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
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.25),
                    Colors.teal.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.timer, color: Colors.green.shade700, size: 22),
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
            UserCardWidget._buildRenewalButton(context, ref, userInfo),
          ],
        );
      },
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final block = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
    return Shimmer(
      child: Container(
        height: 210,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.colorScheme.outline.withOpacity(0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block,
                      const SizedBox(height: 10),
                      SizedBox(width: 120, child: block),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            block,
            const SizedBox(height: 14),
            block,
          ],
        ),
      ),
    );
  }
}




