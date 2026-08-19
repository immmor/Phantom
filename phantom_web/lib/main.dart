import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'core/controller.dart';

/// 远程网页地址。
///
/// 默认指向本地服务器（python3 -m http.server 8000，服务 `website/` 目录）。
/// 可用 `--dart-define=WEB_URL=https://your.domain/page` 覆盖；
/// 之后想更新 UI 只需修改服务器上的网页代码，无需重新打包 App。
const String webUrl = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'http://127.0.0.1:5500/phantom_web/website/index.html',
);

void main() {
  runApp(const PhantomWebApp());
}

class PhantomWebApp extends StatelessWidget {
  const PhantomWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phantom Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const WebShellPage(),
    );
  }
}

/// WebView 壳主页面。
class WebShellPage extends StatefulWidget {
  const WebShellPage({super.key});

  @override
  State<WebShellPage> createState() => _WebShellPageState();
}

class _WebShellPageState extends State<WebShellPage> {
  late final WebViewController _controller;
  final CoreController _core = CoreController();

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // JS 桥接通道：网页内通过
      // window.PhantomShell.postMessage(JSON.stringify({...})) 与壳通信。
      // 壳解析后调用 Clash 内核，结果通过 window.PhantomBridge.emit 推回网页。
      ..addJavaScriptChannel(
        'PhantomShell',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            if (!kIsWeb) {
              setState(() => _error = error.description);
            }
          },
        ),
      );

    // 内核状态/事件 → 推给网页
    _core.onMessage = (message) {
      _emitToWeb(message);
    };

    _controller.loadRequest(Uri.parse(webUrl));
  }

  /// 网页请求 → 内核；结果回推网页。
  Future<void> _handleBridgeMessage(String raw) async {
    debugPrint('[PhantomShell] $raw');
    Map<String, dynamic> req;
    try {
      req = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      _emitToWeb({'code': -1, 'error': 'invalid json: $e'});
      return;
    }
    final result = await _core.handleRequest(req);
    _emitToWeb(jsonDecode(result));
  }

  /// 推消息给网页：window.PhantomBridge.emit(msg)。
  void _emitToWeb(dynamic message) {
    if (!mounted) return;
    final json = jsonEncode(message);
    _controller.runJavaScript(
      'window.PhantomBridge && window.PhantomBridge.emit && '
      'window.PhantomBridge.emit($json);',
    );
  }

  void _reload() {
    setState(() => _error = null);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          // 顶部加载进度条
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          // 加载失败时覆盖错误页
          if (_error != null)
            Positioned.fill(
              child: WebShellErrorView(
                url: webUrl,
                error: _error!,
                onRetry: _reload,
              ),
            ),
        ],
      ),
    );
  }
}

/// 加载失败提示页。
class WebShellErrorView extends StatelessWidget {
  const WebShellErrorView({
    super.key,
    required this.url,
    required this.error,
    required this.onRetry,
  });

  final String url;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                '页面加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                url,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
