/// 内核通信枚举与模型（从主项目 fl_clash 移植的精简版，去掉依赖）。
library core_models;

/// 内核 Action 方法（与 core/constant.go 的 ActionMethod 一一对应）。
enum ActionMethod {
  message,
  initClash,
  getIsInit,
  forceGc,
  shutdown,
  validateConfig,
  updateConfig,
  getConfig,
  getProxies,
  changeProxy,
  getTraffic,
  getTotalTraffic,
  resetTraffic,
  asyncTestDelay,
  getConnections,
  closeConnections,
  resetConnections,
  closeConnection,
  getExternalProviders,
  getExternalProvider,
  updateGeoData,
  updateExternalProvider,
  sideLoadExternalProvider,
  startLog,
  stopLog,
  startListener,
  stopListener,
  getCountryCode,
  getMemory,
  crash,
  setupConfig,
  deleteFile,
}

/// 调用结果类型。
enum ResultType {
  success,
  error;

  static ResultType fromCode(int? code) {
    return code == null || code == 0 ? ResultType.success : ResultType.error;
  }
}

/// 内核事件类型。
enum CoreEventType {
  log,
  delay,
  request,
  loaded,
  crash;

  static CoreEventType fromName(String? name) {
    return CoreEventType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CoreEventType.crash,
    );
  }
}

/// 请求体：`{"id":"...","method":"initClash","data":"..."}`。
class Action {
  const Action({required this.id, required this.method, this.data});

  final String id;
  final ActionMethod method;
  final dynamic data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method.name,
        'data': data,
      };
}

/// 响应体：`{"id":"...","method":"initClash","data":true,"code":0}`。
/// id 为空的响应表示事件（method=message, data 为 CoreEvent JSON）。
class ActionResult {
  const ActionResult({
    required this.method,
    required this.data,
    this.id,
    this.code = ResultType.success,
  });

  factory ActionResult.fromJson(Map<String, dynamic> json) {
    return ActionResult(
      method: ActionMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => ActionMethod.message,
      ),
      data: json['data'],
      id: json['id'],
      code: ResultType.fromCode(json['code'] as int?),
    );
  }

  final ActionMethod method;
  final dynamic data;
  final String? id;
  final ResultType code;
}

/// 内核事件：`{"type":"log","data":{...}}`。
class CoreEvent {
  const CoreEvent({required this.type, this.data});

  factory CoreEvent.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const CoreEvent(type: CoreEventType.crash, data: 'invalid event');
    }
    return CoreEvent(
      type: CoreEventType.fromName(json['type'] as String?),
      data: json['data'],
    );
  }

  final CoreEventType type;
  final dynamic data;
}

/// initClash 参数：`{"home-dir":"...","version":1}`。
class InitParams {
  const InitParams({required this.homeDir, this.version = 1});

  factory InitParams.fromJson(Map<String, dynamic> json) => InitParams(
        homeDir: json['home-dir'] as String,
        version: (json['version'] as num?)?.toInt() ?? 1,
      );

  final String homeDir;
  final int version;

  Map<String, dynamic> toJson() => {'home-dir': homeDir, 'version': version};
}

/// setupConfig 参数：`{"selected-map":{},"test-url":"..."}`。
class SetupParams {
  const SetupParams({
    this.selectedMap = const {},
    this.testUrl = 'https://www.gstatic.com/generate_204',
  });

  final Map<String, String> selectedMap;
  final String testUrl;

  Map<String, dynamic> toJson() => {
        'selected-map': selectedMap,
        'test-url': testUrl,
      };
}

/// changeProxy 参数：`{"group-name":"GLOBAL","proxy-name":"节点A"}`。
class ChangeProxyParams {
  const ChangeProxyParams({required this.groupName, required this.proxyName});

  final String groupName;
  final String proxyName;

  Map<String, dynamic> toJson() => {
        'group-name': groupName,
        'proxy-name': proxyName,
      };
}

/// getProxies 返回：`{"proxies":{...},"all":[...]}`。
class ProxiesData {
  const ProxiesData({required this.proxies, required this.all});

  factory ProxiesData.fromJson(Map<String, dynamic> json) => ProxiesData(
        proxies: (json['proxies'] as Map<String, dynamic>?) ?? {},
        all: ((json['all'] as List?) ?? []).cast<String>(),
      );

  final Map<String, dynamic> proxies;
  final List<String> all;
}
