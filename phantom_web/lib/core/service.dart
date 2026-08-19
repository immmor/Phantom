import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'models.dart';

/// 内核进程服务（从主项目 fl_clash 的 CoreService 移植的精简版）。
///
/// 机制：
/// 1. bind 一个 unix socket（/tmp/FlClashSocket_xxx.sock）
/// 2. `Process.start(corePath, [socketPath])` 启动内核，内核反向连接
/// 3. 之后通过 socket 交换行式 JSON：`{"id":"...","method":"initClash","data":"..."}`
/// 4. 响应 `{id, method, data, code}`；id 为空的响应是事件（method=message）
class CoreService {
  CoreService._internal() {
    _initServer();
  }

  static final CoreService _instance = CoreService._internal();

  factory CoreService() => _instance;

  final Map<String, Completer<ActionResult>> _callbackCompleterMap = {};
  final Set<String> _ackMethods = {'updateGeoData', 'updateExternalProvider'};

  ServerSocket? _server;
  Socket? _coreClient;
  Process? _process;
  String _socketPath = '';

  bool _isServerListening = false;
  bool _isDestroyed = false;
  Completer<void>? _serverReady;

  /// 最近一次启动失败的具体原因（供 UI 展示）。
  String _lastStartError = '';

  /// 最近一次启动失败时的内核 stderr 日志。
  final List<String> _lastStderr = [];

  /// 内核进程退出码（进程存活时为 null）。
  int? _exitCode;

  /// 最近一次 `start()` 失败的具体原因；空串表示最近一次启动未失败。
  String get lastStartError => _lastStartError;

  /// 内核事件回调（log / delay / request / loaded / crash）。
  void Function(CoreEvent event)? onEvent;

  /// 内核二进制路径（App 的 Contents/MacOS/FlClashCore）。
  String get corePath {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    return p.join(executableDir, 'FlClashCore');
  }

  /// bind unix socket，等待内核反向连接。
  void _initServer() {
    if (_isServerListening) return;
    _serverReady = Completer<void>();
    _socketPath = p.join(
      Directory.systemTemp.path,
      'FlClashSocket_${Random().nextInt(10000)}.sock',
    );
    ServerSocket.bind(
      InternetAddress(_socketPath, type: InternetAddressType.unix),
      0,
    ).then((server) {
      _server = server;
      _isServerListening = true;
      _server!.listen((client) {
        _coreClient?.destroy();
        _coreClient = client;
        _handleCoreClient(client);
      });
      _serverReady?.complete();
    }).catchError((Object e) {
      _serverReady?.completeError(e);
    });
  }

  /// 处理内核连接：按行解析 JSON，事件 vs 响应分流。
  void _handleCoreClient(Socket client) {
    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleAction,
          onError: (_) {},
          onDone: () {
            _coreClient = null;
          },
        );
  }

  void _handleAction(String line) {
    if (line.trim().isEmpty) return;
    try {
      final result = ActionResult.fromJson(
        jsonDecode(line) as Map<String, dynamic>,
      );
      final id = result.id ?? '';
      if (id.isEmpty) {
        // 事件推送：{"id":"","method":"message","data":{...}}
        if (result.method == ActionMethod.message) {
          onEvent?.call(CoreEvent.fromJson(result.data));
        }
        return;
      }
      _callbackCompleterMap.remove(id)?.complete(result);
    } catch (e) {
      // ignore malformed lines
    }
  }

  /// 启动内核进程。
  ///
  /// 返回 true 表示内核已通过 socket 反连；false 表示失败，
  /// 具体原因可通过 [lastStartError] 获取（含内核 stderr 日志）。
  Future<bool> start() async {
    await _serverReady?.future;
    if (_isDestroyed) return false;

    _lastStartError = '';
    _lastStderr.clear();
    _exitCode = null;

    // 1. 二进制存在性检查（Copy Core 构建阶段是否生效）
    final coreFile = File(corePath);
    if (!coreFile.existsSync()) {
      _lastStartError = '内核二进制不存在：$corePath\n'
          '请检查 Xcode 工程 "Copy Core" 构建阶段，'
          '是否把 libclash/macos/FlClashCore 拷贝进了 App 的 Contents/MacOS/。';
      return false;
    }

    // 2. 启动进程，异常不再吞掉（缺失动态库 / 架构不符 / 权限等会在此暴露）
    try {
      _process = await Process.start(corePath, [_socketPath]);
    } catch (e) {
      _lastStartError = '内核进程启动失败：$e';
      return false;
    }

    // 3. 收集内核 stdout/stderr（启动错误、config 加载错误都从这里看）
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {});
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      _lastStderr.add(trimmed);
      if (_lastStderr.length > 20) _lastStderr.removeAt(0);
    });

    // 4. 记录进程退出码（用于判断"启动后立即崩溃"）
    _process!.exitCode.then((code) {
      _exitCode = code;
    });

    // 5. 等待内核反向连接（最多 5 秒）
    for (var i = 0; i < 100; i++) {
      if (_coreClient != null) return true;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final stderrText = _lastStderr.isEmpty
        ? '（无内核日志输出）'
        : '内核日志：\n${_lastStderr.join('\n')}';
    if (_exitCode != null) {
      _lastStartError = '内核启动后立即退出（exit $_exitCode）。$stderrText\n'
          '常见原因：端口被占用（订阅配置里的 port/socks-port/external-controller）'
          '或 config.yaml 解析失败。';
    } else {
      _lastStartError = '内核未在 5 秒内连接（进程存活但无响应）。$stderrText';
    }
    return false;
  }

  /// 发送 action 并等待响应。
  Future<dynamic> invoke(ActionMethod method, [dynamic data]) async {
    final id = '${method.name}#${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<ActionResult>();
    _callbackCompleterMap[id] = completer;
    try {
      _coreClient?.write(
        '${jsonEncode(Action(id: id, method: method, data: data))}\n',
      );
    } catch (e) {
      _callbackCompleterMap.remove(id);
      throw StateError('core socket write failed: $e');
    }

    final result = await completer.future.timeout(const Duration(seconds: 15));
    if (result.code != ResultType.success) {
      throw StateError(
        'action ${method.name} failed: ${result.data}',
      );
    }
    return result.data;
  }

  // ── 便捷方法 ──────────────────────────────────────────

  /// initClash：设置 home-dir，返回 version。
  Future<bool> initClash(InitParams params) async {
    return await invoke(ActionMethod.initClash, params.toJson()) == 1;
  }

  /// setupConfig：从 home-dir/config.yaml 加载配置。
  Future<void> setupConfig(SetupParams params) async {
    await invoke(ActionMethod.setupConfig, params.toJson());
  }

  /// 启动监听端口。
  Future<void> startListener() async {
    await invoke(ActionMethod.startListener);
  }

  /// 停止监听端口。
  Future<void> stopListener() async {
    await invoke(ActionMethod.stopListener);
  }

  /// 优雅关闭内核。
  Future<void> shutdown() async {
    try {
      await invoke(ActionMethod.shutdown);
    } catch (_) {}
  }

  /// 获取代理列表。
  Future<ProxiesData> getProxies() async {
    final data = await invoke(ActionMethod.getProxies);
    return ProxiesData.fromJson(data as Map<String, dynamic>);
  }

  /// 切换分组内代理。
  Future<void> changeProxy(ChangeProxyParams params) async {
    await invoke(ActionMethod.changeProxy, params.toJson());
  }

  /// 获取累计流量（bytes，{up, down}）。
  Future<Map<String, int>> getTotalTraffic() async {
    final data = await invoke(ActionMethod.getTotalTraffic);
    final map = data as Map<String, dynamic>;
    return {
      'up': (map['up'] as num).toInt(),
      'down': (map['down'] as num).toInt(),
    };
  }

  /// 开启日志推送。
  Future<void> startLog() async {
    await invoke(ActionMethod.startLog);
  }

  /// 关闭日志推送。
  Future<void> stopLog() async {
    await invoke(ActionMethod.stopLog);
  }

  /// 清理资源。
  Future<void> destroy() async {
    if (_isDestroyed) return;
    _isDestroyed = true;
    try {
      await shutdown();
    } catch (_) {}
    try {
      _process?.kill();
    } catch (_) {}
    try {
      await _server?.close();
    } catch (_) {}
    try {
      _coreClient?.destroy();
    } catch (_) {}
    _process = null;
    _coreClient = null;
    _server = null;
    _isServerListening = false;
  }
}
