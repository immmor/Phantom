import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'widgets.dart';

class LoginDialog extends ConsumerStatefulWidget {
  const LoginDialog({super.key});

  @override
  ConsumerState<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<LoginDialog> {
  final _user = TextEditingController();
  final _pwd = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _user.text.trim();
    final password = _pwd.text;
    if (username.isEmpty || password.isEmpty) {
      _error('用户名和密码不能为空');
      return;
    }

    setState(() => _loading = true);

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
        'https://api.immmor.com/api/login',
        data: {'username': username, 'password': password},
      );

      if (res.data['success'] == true) {
        final userInfo = res.data['userInfo'];
        final username = userInfo?['username'] as String?;
        final vToken = userInfo?['v_token'] as String?;
        final vExpireDate = userInfo?['v_expire_date'] as String?;
        final balance = (userInfo?['balance'] as num?)?.toDouble();
        await preferences.setLastLoginTime(DateTime.now());
        await preferences.setUsername(username);
        await preferences.setVToken(vToken);
        await preferences.setVExpireDate(vExpireDate);
        await preferences.setBalance(balance);

        if (mounted) {
          // 刷新用户信息
          ref.invalidate(phantomHomeProvider);
          Navigator.of(context).pop(true);
          
          // 延迟添加订阅，等待应用初始化完成
          Future.delayed(const Duration(seconds: 2), () {
            _addSubscriptions(vToken, vExpireDate, username);
          });
        }
      } else {
        _error(res.data['message'] ?? '登录失败');
      }
    } on DioException catch (e) {
      _error('网络错误：${e.message}');
    } catch (e) {
      _error('登录出错：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSubscriptions(String? vToken, String? vExpireDate, String? username) async {
    final container = globalState.container;
    if (container == null) return;

    // 先删除所有已有订阅
    _clearAllProfiles(container);

    // 判断是否是有效会员
    final isVip = vToken != null &&
        vToken.isNotEmpty &&
        vExpireDate != null &&
        DateTime.tryParse(vExpireDate)?.isAfter(DateTime.now()) == true;

    if (isVip) {
      // 会员：下载两个节点，激活会员节点
      await _addProfile(container, 'https://api.immmor.com/vip/clash?v=$vToken', 'VIP 节点', true);
    } else {
      // 非会员：只下载免费节点并激活
      await _addProfile(container, 'https://api.immmor.com/free/clash?username=$username', '免费节点', true);
    }
  }

  void _clearAllProfiles(ProviderContainer container) {
    try {
      final profiles = container.read(profilesProvider);
      final notifier = container.read(profilesProvider.notifier);
      for (final profile in profiles) {
        notifier.del(profile.id);
      }
      // 清除当前选中的配置
      container.read(currentProfileIdProvider.notifier).value = null;
    } catch (e) {
      debugPrint('清除订阅失败：$e');
    }
  }

  Future<void> _addProfile(ProviderContainer container, String url, String label, bool autoSelect) async {
    try {
      var profile = Profile.normal(
        label: label,
        url: url,
      );

      // 下载订阅内容
      profile = await profile.update();

      // 保存到数据库
      container.read(profilesProvider.notifier).put(profile);

      // 如果是免费节点且需要自动选择，则设置为当前使用的配置
      if (autoSelect) {
        container.read(currentProfileIdProvider.notifier).value = profile.id;
      }
    } catch (e) {
      debugPrint('添加订阅失败：$e');
    }
  }

  void _error(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '登录',
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/phantom.svg', width: 64, height: 64),
          const SizedBox(height: 16),
          Text(appName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwd,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }
}
