import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          SwissBackground(
            accent: context.colorScheme.primary,
            glowAlpha: 0.09,
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: _buildPageHeader(context),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: StaggeredList(
                      padding: const EdgeInsets.only(bottom: 20),
                      gap: 10,
                      duration: const Duration(milliseconds: 500),
                      children: [
                        const UserCardWidget(),
                        const SizedBox(height: 4),
                        _buildSettingsGroup(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 页面品牌头：与首页一致的瑞士极简排版
  Widget _buildPageHeader(BuildContext context) {
    final outline = context.colorScheme.outline;
    return Column(
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
          '我的账户',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: context.colorScheme.onSurfaceVariant.opacity60,
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: outline.withValues(alpha: 0.12)),
      ],
    );
  }

  /// 设置项：玻璃面板 + 1px 结构线，延续首页的克制排版
  Widget _buildSettingsGroup(BuildContext context) {
    final outline = context.colorScheme.outline;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 6),
      borderRadius: BorderRadius.circular(20),
      blur: 18,
      tintOpacity: 0.35,
      borderOpacity: 0.7,
      boxShadow: const [],
      child: Column(
        children: [
          const _LocaleItem(),
          _buildHairline(outline),
          if (system.isAndroid) ...[
            const _AccessItem(),
            _buildHairline(outline),
          ],
          const _InfoItem(),
          _buildHairline(outline),
          const _LoginItem(),
        ],
      ),
    );
  }

  Widget _buildHairline(Color outline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: outline.withValues(alpha: 0.1)),
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(Locale? locale) {
    if (locale == null) return appLocalizations.defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const Icon(Icons.language_outlined),
      title: Text(context.appLocalizations.language),
      delegate: OptionsDelegate(
        title: context.appLocalizations.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (Locale? locale) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(locale: locale?.toString()));
        },
        textBuilder: (locale) => _getLocaleString(locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.style),
      title: Text(context.appLocalizations.theme),
      delegate: OpenDelegate(widget: const ThemeView()),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.info),
      title: Text(context.appLocalizations.about),
      delegate: OpenDelegate(widget: const AboutView()),
    );
  }
}

class _ClearCacheItem extends ConsumerWidget {
  const _ClearCacheItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListItem(
      leading: const Icon(Icons.cleaning_services),
      title: const Text('清除缓存'),
      onTap: () => _showClearCacheDialog(context, ref),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) async {
    final cacheInfo = await _getCacheInfo(ref);
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当前缓存内容：'),
              const SizedBox(height: 12),
              ...cacheInfo.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(info['label']!, style: const TextStyle(color: Colors.grey)),
                    Text(info['value']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              const Text(
                '清除缓存不会删除您的配置和账户数据。',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleClearCache(context, ref);
            },
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, String>>> _getCacheInfo(WidgetRef ref) async {
    final cachedUp = await preferences.getCachedTotalUpTraffic() ?? 0;
    final cachedDown = await preferences.getCachedTotalDownTraffic() ?? 0;
    final lastLoginTime = await preferences.getLastLoginTime();
    final lastCheckInDate = await preferences.getLastCheckInDate();
    
    return [
      {
        'label': '累计上传流量',
        'value': (cachedUp / 1024 / 1024).toStringAsFixed(2) + ' MB',
      },
      {
        'label': '累计下载流量',
        'value': (cachedDown / 1024 / 1024).toStringAsFixed(2) + ' MB',
      },
      {
        'label': '总流量',
        'value': ((cachedUp + cachedDown) / 1024 / 1024).toStringAsFixed(2) + ' MB',
      },
      {
        'label': '上次登录时间',
        'value': lastLoginTime != null 
            ? '${lastLoginTime.year}-${lastLoginTime.month.toString().padLeft(2, '0')}-${lastLoginTime.day.toString().padLeft(2, '0')}'
            : '无',
      },
      {
        'label': '上次签到时间',
        'value': lastCheckInDate != null
            ? '${lastCheckInDate.year}-${lastCheckInDate.month.toString().padLeft(2, '0')}-${lastCheckInDate.day.toString().padLeft(2, '0')}'
            : '无',
      },
    ];
  }

  void _handleClearCache(BuildContext context, WidgetRef ref) async {
    // 清除流量缓存
    await preferences.setCachedTotalUpTraffic(null);
    await preferences.setCachedTotalDownTraffic(null);
    
    // 清除签到日期缓存（重置为未签到状态）
    await preferences.setLastCheckInDate(DateTime(1970));
    
    // 重置签到奖励流量
    await preferences.setCheckInBonusTraffic(null);
    checkInBonusTraffic.value = 0.0;
    
    // 刷新流量显示
    ref.invalidate(cachedTrafficProvider);
    
    // 刷新签到状态
    ref.invalidate(lastCheckInDateProvider);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('缓存已清除'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _AccessItem extends StatelessWidget {
  const _AccessItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.view_list),
      title: Text(context.appLocalizations.accessControl),
      delegate: OpenDelegate(widget: const AccessView()),
    );
  }
}

class _LoginItem extends ConsumerWidget {
  const _LoginItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phantomHomeAsync = ref.watch(phantomHomeProvider);

    return phantomHomeAsync.when(
      data: (userInfo) {
        if (userInfo == null) {
          return ListItem(
            leading: const Icon(Icons.login),
            title: const Text('登录'),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const LoginDialog(),
            ),
          );
        }
        return ListItem(
          leading: const Icon(Icons.logout),
          title: const Text('退出登录'),
          onTap: () => _handleLogout(context, ref),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await globalState.showMessage(
      title: '确认退出',
      message: const TextSpan(text: '确定要退出登录吗？'),
      confirmText: '退出',
      cancelText: '取消',
    );
    if (confirm == true) {
      // 退出登录时先断开当前连接
      if (ref.read(isStartProvider)) {
        await appController.updateStatus(false);
      }
      await preferences.setLastLoginTime(DateTime(2000));
      await preferences.setUsername(null);
      await preferences.setVToken(null);
      await preferences.setVExpireDate(null);
      await preferences.setVipStartDate(null);
      await preferences.setBalance(null);
      await preferences.setMonthlyQuota(null);
      monthlyQuotaBytes.value = defaultMonthlyQuotaBytes;
      // 切到未登录账号的数据，不会删除原账号的数据
      await reloadAccountScopedCache(
        ProviderScope.containerOf(context, listen: false),
      );
      ref.invalidate(phantomHomeProvider);
    }
  }
}