import 'dart:convert';

import 'config.dart';
import 'models.dart';
import 'service.dart';

/// 内核生命周期状态。
enum CoreStatus { idle, connecting, connected, error }

/// 内核高层控制器：封装 initClash → setupConfig → startListener 流程，
/// 并向 UI（JS Bridge）暴露事件。
class CoreController {
  CoreController._() {
    _service.onEvent = _handleEvent;
  }

  static final CoreController _instance = CoreController._();

  factory CoreController() => _instance;

  final CoreService _service = CoreService();

  CoreStatus _status = CoreStatus.idle;
  String _error = '';

  CoreStatus get status => _status;
  String get error => _error;

  /// 状态/事件变化回调（供 JS Bridge 转发给网页）。
  void Function(dynamic message)? onMessage;

  /// 网页请求（connect / disconnect / select-server / get-proxies / get-traffic）
  /// 的统一入口。返回可直接回传网页的 JSON 字符串。
  Future<String> handleRequest(Map<String, dynamic> req) async {
    final type = req['type'] as String? ?? '';
    try {
      switch (type) {
        case 'connect':
          await connect();
          return _ok({'type': 'connected'});
        case 'disconnect':
          await disconnect();
          return _ok({'type': 'disconnected'});
        case 'get-proxies':
          final data = await _service.getProxies();
          return _ok({'type': 'proxies', 'data': _proxiesToSimple(data)});
        case 'change-proxy':
          final group = req['group'] as String? ?? 'GLOBAL';
          final proxy = req['proxy'] as String? ?? '';
          await _service.changeProxy(
            ChangeProxyParams(groupName: group, proxyName: proxy),
          );
          return _ok({'type': 'changed', 'group': group, 'proxy': proxy});
        case 'get-traffic':
          final t = await _service.getTotalTraffic();
          return _ok({'type': 'traffic', 'up': t['up'], 'down': t['down']});
        case 'load-config':
          final url = (req['url'] as String? ?? '').trim();
          if (url.isEmpty) {
            return _err('订阅链接不能为空');
          }
          try {
            final err = await CoreConfig.applySubscription(url);
            if (err.isNotEmpty) {
              return _err(err);
            }
          } catch (e) {
            return _err('订阅下载失败：$e');
          }
          // 已连接时重启内核以加载新订阅
          if (_status == CoreStatus.connected) {
            await disconnect();
            await connect();
          }
          return _ok({'type': 'config-loaded', 'url': url});
        default:
          return _err('unknown request: $type');
      }
    } catch (e) {
      return _err(e.toString());
    }
  }

  /// 建立连接：initClash → setupConfig → startListener → startLog。
  Future<void> connect() async {
    if (_status == CoreStatus.connected ||
        _status == CoreStatus.connecting) {
      return;
    }
    _setStatus(CoreStatus.connecting);
    try {
      CoreConfig.ensure();
      final started = await _service.start();
      if (!started) {
        final detail = _service.lastStartError;
        throw StateError(
          detail.isEmpty ? 'core process failed to start' : detail,
        );
      }
      await _service.initClash(InitParams(homeDir: CoreConfig.homeDir));
      await _service.setupConfig(const SetupParams());
      await _service.startListener();
      await _service.startLog();
      _setStatus(CoreStatus.connected);
    } catch (e) {
      _error = e.toString();
      _setStatus(CoreStatus.error);
      rethrow;
    }
  }

  /// 断开连接：stopListener → shutdown。
  Future<void> disconnect() async {
    if (_status == CoreStatus.idle) return;
    try {
      await _service.stopListener();
    } catch (_) {}
    try {
      await _service.shutdown();
    } catch (_) {}
    _setStatus(CoreStatus.idle);
  }

  /// 获取当前 GLOBAL 分组下的节点列表（简化为网页可用结构）。
  Map<String, dynamic> _proxiesToSimple(ProxiesData data) {
    final all = data.all;
    return {
      'all': all,
      'global': all
          .where((name) => name != 'GLOBAL' && name != 'DIRECT' && name != 'REJECT')
          .toList(),
    };
  }

  void _handleEvent(CoreEvent event) {
    if (event.type == CoreEventType.loaded) {
      _setStatus(CoreStatus.connected);
    }
    onMessage?.call({
      'type': 'event',
      'eventType': event.type.name,
      'data': event.data,
    });
  }

  void _setStatus(CoreStatus status) {
    _status = status;
    onMessage?.call({
      'type': 'status',
      'status': status.name,
      if (status == CoreStatus.error && _error.isNotEmpty) 'error': _error,
    });
  }

  String _ok(Map<String, dynamic> data) {
    data['code'] = 0;
    return jsonEncode(data);
  }

  String _err(String message) {
    return jsonEncode({'code': -1, 'error': message});
  }
}
