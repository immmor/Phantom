import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// home-dir 与默认 config.yaml 管理（移植自主项目 AppPath/Profile 逻辑的精简版）。
class CoreConfig {
  CoreConfig._();

  /// 无订阅时的默认配置内容（mihomo 格式）。
  static const String defaultConfigYaml = '''
# Phantom Web 默认配置（由壳首次启动时生成）
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false

proxies:
  - name: "Example-SS"
    type: ss
    server: 127.0.0.1
    port: 8388
    cipher: aes-256-gcm
    password: "change-me"

proxy-groups:
  - name: "GLOBAL"
    type: select
    proxies:
      - "Example-SS"
      - DIRECT

rules:
  - MATCH,GLOBAL
''';

  /// macOS 的 home-dir：~/Library/Application Support/PhantomWeb
  /// （沙盒内会自动重定向到容器对应目录）。
  static String get homeDir {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, 'Library', 'Application Support', 'PhantomWeb');
  }

  static String get configPath => p.join(homeDir, 'config.yaml');

  static String get subscriptionPath => p.join(homeDir, 'subscription.txt');

  static String get providersDir => p.join(homeDir, 'providers');

  /// 确保 home-dir 存在，并在缺少 config.yaml 时写入默认配置。
  static void ensure() {
    final dir = Directory(homeDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final config = File(configPath);
    if (!config.existsSync()) {
      writeConfig(defaultConfigYaml);
    }
  }

  /// 覆盖写入配置内容。
  static void writeConfig(String yaml) {
    ensure();
    File(configPath).writeAsStringSync(yaml);
  }

  /// 已保存的订阅链接（无则返回 null）。
  static String? getSubscription() {
    final f = File(subscriptionPath);
    if (!f.existsSync()) return null;
    final s = f.readAsStringSync().trim();
    return s.isEmpty ? null : s;
  }

  /// 下载订阅内容并应用为 config.yaml（与主项目 FlClash 一致的做法：
  /// 订阅链接直接返回完整 Clash 配置，原样保存，重启内核后整体加载）。
  ///
  /// 返回空字符串表示成功，否则返回给用户的错误提示。
  static Future<String> applySubscription(String url) async {
    ensure();
    final trimmed = url.trim();

    final content = await _download(trimmed);
    if (content.isEmpty) {
      return '订阅下载失败：内容为空';
    }

    // 判断内容格式：
    // 1. 完整/部分 Clash YAML 配置（含 proxies: 或 proxy-providers:）→ 原样使用
    // 注意：Dart RegExp 不支持 (?m) 内联修饰符，须用 multiLine: true
    final hasProxies =
        RegExp(r'^\s*proxies:\s*', multiLine: true).hasMatch(content);
    final hasProviders =
        RegExp(r'^\s*proxy-providers:\s*', multiLine: true).hasMatch(content);
    if (hasProxies || hasProviders) {
      writeConfig(content);
      File(subscriptionPath).writeAsStringSync(trimmed);
      return '';
    }

    // 2. base64 编码的节点链接列表 → 尝试解码给出明确提示
    final decoded = _tryDecodeBase64(content);
    if (decoded != null) {
      return '订阅返回的是节点链接列表（base64），当前仅支持完整 Clash 配置订阅。'
          '请确认链接带 ?clash=3 等参数以获取完整配置。';
    }

    return '订阅内容不是有效的 Clash 配置（未找到 proxies: 字段）';
  }

  /// 下载订阅内容（utf-8 文本），使用浏览器 UA 以避免服务端拦截。
  /// 与主项目 FlClash 对齐：
  /// - 接受所有 TLS 证书（badCertificateCallback），避免订阅商证书链问题导致失败
  /// - 强制直连（不走系统/环境代理），避免残留代理设置导致失败
  /// - 严格超时，避免下载挂起阻塞消息循环
  static Future<String> _download(String url) async {
    const browserUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final client = HttpClient()
      ..userAgent = browserUa
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 20)
      ..badCertificateCallback = (_, _, _) => true; // 与主项目一致：接受所有证书
    client.findProxy = (_) => 'DIRECT'; // 强制直连，不走系统代理

    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final resp = await req.close().timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw StateError('HTTP ${resp.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in resp) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } on TimeoutException {
      throw StateError('连接超时');
    } on SocketException catch (e) {
      throw StateError('网络连接失败（${e.message}）');
    } on HttpException catch (e) {
      throw StateError('HTTP 请求失败（${e.message}）');
    } finally {
      client.close(force: true);
    }
  }

  /// 尝试把内容当作 base64 节点列表解码；成功且含节点链接时返回解码文本。
  static String? _tryDecodeBase64(String content) {
    final compact = content.replaceAll(RegExp(r'\s'), '');
    if (compact.length < 20) return null;
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(compact)) return null;
    try {
      final decoded = utf8.decode(base64.decode(compact), allowMalformed: true);
      if (decoded.contains('://')) return decoded;
    } catch (_) {}
    return null;
  }
}
