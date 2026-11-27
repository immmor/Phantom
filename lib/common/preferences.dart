import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

final _usernameKey = 'username';

class Preferences {
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, _) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<int> getVersion() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt('version') ?? 0;
  }

  Future<void> setVersion(int version) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt('version', version);
  }

  Future<void> saveShareState(SharedState shareState) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString('sharedState', json.encode(shareState));
  }

  Future<Map<String, Object?>?> getConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final configString = preferences?.getString(configKey);
      if (configString == null) return null;
      final Map<String, Object?>? configMap = json.decode(configString);
      return configMap;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> getClashConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final clashConfigString = preferences?.getString(clashConfigKey);
      if (clashConfigString == null) return null;
      return json.decode(clashConfigString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearClashConfig() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      await preferences?.remove(clashConfigKey);
      return;
    } catch (_) {
      return;
    }
  }

  Future<Config?> getConfig() async {
    final configMap = await getConfigMap();
    if (configMap == null) {
      return null;
    }
    return Config.fromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.setString(configKey, json.encode(config)) ?? false;
  }

  Future<DateTime?> getLastLoginTime() async {
    final preferences = await sharedPreferencesCompleter.future;
    final timestamp = preferences?.getInt('lastLoginTime');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> setLastLoginTime(DateTime time) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt('lastLoginTime', time.millisecondsSinceEpoch);
  }

  /// 账号维度的本地 key：同一设备上不同账号各自保留自己的签到/流量数据。
  Future<String> _accountKey(String key) async {
    final username = await getUsername();
    if (username == null || username.isEmpty) return key;
    return '$key@$username';
  }

  /// 一次性迁移：旧版本的数据是按设备存的，升级后归到当前账号名下，
  /// 避免登录看起来像被清零。之后各账号独立保存。
  Future<void> migrateLegacyAccountCache() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return;
    if (preferences.getBool('accountCacheMigrated') == true) return;
    final username = preferences.getString(_usernameKey);
    if (username == null || username.isEmpty) return;

    Future<void> migrate(String key) async {
      final scopedKey = '$key@$username';
      if (preferences.containsKey(scopedKey)) return;
      final value = preferences.get(key);
      if (value is int) {
        await preferences.setInt(scopedKey, value);
      } else if (value is double) {
        await preferences.setDouble(scopedKey, value);
      }
    }

    await migrate('lastCheckInDate');
    await migrate('cachedTotalUpTraffic');
    await migrate('cachedTotalDownTraffic');
    await preferences.setBool('accountCacheMigrated', true);
  }

  Future<DateTime?> getLastCheckInDate() async {
    final preferences = await sharedPreferencesCompleter.future;
    final timestamp = preferences?.getInt(await _accountKey('lastCheckInDate'));
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> setLastCheckInDate(DateTime date) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt(
      await _accountKey('lastCheckInDate'),
      date.millisecondsSinceEpoch,
    );
  }

  Future<String?> getVToken() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getString('vToken');
  }

  Future<void> setVToken(String? token) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (token != null) {
      await preferences?.setString('vToken', token);
    } else {
      await preferences?.remove('vToken');
    }
  }

  Future<String?> getVExpireDate() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getString('vExpireDate');
  }

  Future<String?> getUsername() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getString(_usernameKey);
  }

  Future<void> setUsername(String? username) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (username != null) {
      await preferences?.setString(_usernameKey, username);
    } else {
      await preferences?.remove(_usernameKey);
    }
  }

  Future<void> setVExpireDate(String? date) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (date != null) {
      await preferences?.setString('vExpireDate', date);
    } else {
      await preferences?.remove('vExpireDate');
    }
  }

  /// VIP 本轮权益的起始时间（首次开通 / 过期后重新开通的时刻）。
  /// 已购总时长 = 到期时间 − 该起始时间（多次叠加续费会自然累加）
  Future<String?> getVipStartDate() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getString('vipStartDate');
  }

  Future<void> setVipStartDate(String? date) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (date != null) {
      await preferences?.setString('vipStartDate', date);
    } else {
      await preferences?.remove('vipStartDate');
    }
  }

  Future<double?> getBalance() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble('balance');
  }

  Future<void> setBalance(double? balance) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (balance != null) {
      await preferences?.setDouble('balance', balance);
    } else {
      await preferences?.remove('balance');
    }
  }

  /// 每月基础流量配额，单位 MB（后端 monthly_quota）
  Future<double?> getMonthlyQuota() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble('monthlyQuota');
  }

  Future<void> setMonthlyQuota(double? quota) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (quota != null) {
      await preferences?.setDouble('monthlyQuota', quota);
    } else {
      await preferences?.remove('monthlyQuota');
    }
  }

  Future<Map<String, dynamic>?> getPricePlan() async {
    final preferences = await sharedPreferencesCompleter.future;
    final str = preferences?.getString('pricePlan');
    if (str == null) {
      return null;
    }
    try {
      return json.decode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPricePlan(Map<String, dynamic>? pricePlan) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (pricePlan != null) {
      await preferences?.setString('pricePlan', json.encode(pricePlan));
    } else {
      await preferences?.remove('pricePlan');
    }
  }

  Future<double?> getCachedTotalUpTraffic() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble(await _accountKey('cachedTotalUpTraffic'));
  }

  Future<void> setCachedTotalUpTraffic(double? value) async {
    final preferences = await sharedPreferencesCompleter.future;
    final key = await _accountKey('cachedTotalUpTraffic');
    if (value != null) {
      await preferences?.setDouble(key, value);
    } else {
      await preferences?.remove(key);
    }
  }

  Future<double?> getCachedTotalDownTraffic() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble(await _accountKey('cachedTotalDownTraffic'));
  }

  Future<void> setCachedTotalDownTraffic(double? value) async {
    final preferences = await sharedPreferencesCompleter.future;
    final key = await _accountKey('cachedTotalDownTraffic');
    if (value != null) {
      await preferences?.setDouble(key, value);
    } else {
      await preferences?.remove(key);
    }
  }

  /// 签到奖励流量（字节），按账号保存。
  Future<double?> getCheckInBonusTraffic() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble(await _accountKey('checkInBonusTraffic'));
  }

  Future<void> setCheckInBonusTraffic(double? value) async {
    final preferences = await sharedPreferencesCompleter.future;
    final key = await _accountKey('checkInBonusTraffic');
    if (value != null) {
      await preferences?.setDouble(key, value);
    } else {
      await preferences?.remove(key);
    }
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
