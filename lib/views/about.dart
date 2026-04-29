import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/pages/login.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CommonCard(
          type: CommonCardType.filled,
          onPressed: () {},
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Consumer(
              builder: (_, ref, _) {
                return _DeveloperModeDetector(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Transform.translate(
                          offset: Offset(0, -1),
                          child: SvgPicture.asset('assets/images/phantom.svg', width: 34, height: 34),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        appName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        globalState.packageInfo.version,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant.opacity80,
                        ),
                      ),
                    ],
                  ),
                  onEnterDeveloperMode: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .update((state) => state.copyWith(developerMode: true));
                    context.showNotifier(
                      appLocalizations.developerModeEnableTip,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CommonCard(
          onPressed: () {},
          radius: 12,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant.opacity80,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FilledButton.tonal(
          onPressed: () => _logout(context),
          child: const Text('退出登录'),
        ),
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.about,
      body: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: generateListView(items),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await globalState.showMessage(
      title: '确认退出',
      message: const TextSpan(text: '确定要退出登录吗？'),
      confirmText: '退出',
      cancelText: '取消',
    );
    if (confirm == true) {
      await preferences.setLastLoginTime(DateTime(2000));
      await preferences.setUsername(null);
      await preferences.setVToken(null);
      await preferences.setVExpireDate(null);
      await preferences.setBalance(null);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
