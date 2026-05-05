import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkInBonusTraffic = ValueNotifier<double>(0.0);

final phantomHomeProvider = FutureProvider<PhantomUserInfo?>((ref) async {
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

Future<String?> renewVip(int duration) async {
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

class RenewButton extends ConsumerWidget {
  final int duration;
  final double price;
  final bool isVip;

  const RenewButton({super.key, required this.duration, required this.price, required this.isVip});

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
          final msg = await renewVip(duration);
          if (msg == null && context.mounted) {
            ref.invalidate(phantomHomeProvider);
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
  @override
  CachedTraffic build() {
    return CachedTraffic();
  }

  Future<void> init() async {
    final cachedUp = await preferences.getCachedTotalUpTraffic() ?? 0;
    final cachedDown = await preferences.getCachedTotalDownTraffic() ?? 0;
    state = CachedTraffic(up: cachedUp, down: cachedDown);
  }

  Future<void> addTraffic(Traffic traffic) async {
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
              height: 200,
              child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatUsername(userInfo.username),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showVipBottomSheet(context, ref, userInfo),
                          child: Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                  size: 16,
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
                        const SizedBox(width: 8),
                        _buildMessageButton(context, ref),
                        const SizedBox(width: 8),
                        _buildCheckInButton(context, ref, isTodayChecked),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTrafficRow(context, ref, userInfo),
                    const SizedBox(height: 8),
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

  static Widget _buildCheckInButton(BuildContext context, WidgetRef ref, bool isTodayChecked) {
    return GestureDetector(
      onTap: isTodayChecked ? null : () => _handleCheckIn(context, ref),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isTodayChecked ? Colors.grey : Colors.orange,
          borderRadius: BorderRadius.circular(4),
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
    await preferences.setLastCheckInDate(DateTime.now());
    ref.invalidate(lastCheckInDateProvider);
    checkInBonusTraffic.value += 50 * 1024 * 1024;
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('签到成功！赠送 50MB 流量'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static Widget _buildMessageButton(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(userMessagesProvider);
    
    return messagesAsync.when(
      data: (messagesData) {
        final unreadCount = messagesData?['unreadCount'] ?? 0;
        final hasUnread = unreadCount > 0;
        
        return GestureDetector(
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
              borderRadius: BorderRadius.circular(4),
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
    return Consumer(
      builder: (context, ref, child) {
        final cachedTraffic = ref.watch(cachedTrafficProvider);
        final currentTraffic = ref.watch(totalTrafficProvider);

        ref.listen(totalTrafficProvider, (previous, next) {
          if (previous == null || (previous.up == 0 && previous.down == 0)) return;
          ref.read(cachedTrafficProvider.notifier).addTraffic(next);
        });

        final usedBytes = cachedTraffic.up + cachedTraffic.down + currentTraffic.up + currentTraffic.down;
        const baseMaxBytes = 2 * 1024 * 1024 * 1024; // 2GB 基础配额
        final maxBytes = baseMaxBytes + checkInBonusTraffic.value; // 总配额 = 2GB + 签到奖励
        final progress = (usedBytes / maxBytes).clamp(0.0, 1.0);
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
    );
  }

  static Widget _buildRenewalButton(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    return GestureDetector(
      onTap: () => _showVipBottomSheet(context, ref, userInfo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

  static void _showVipBottomSheet(BuildContext context, WidgetRef ref, PhantomUserInfo userInfo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final userInfoAsync = ref.watch(phantomHomeProvider);
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
                          child: RenewButton(duration: 30, price: 40, isVip: info.isVip),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RenewButton(duration: 365, price: 450, isVip: info.isVip),
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
            _buildRenewalButton(context, ref, userInfo),
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
