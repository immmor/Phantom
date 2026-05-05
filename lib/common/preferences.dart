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

  Future<DateTime?> getLastCheckInDate() async {
    final preferences = await sharedPreferencesCompleter.future;
    final timestamp = preferences?.getInt('lastCheckInDate');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> setLastCheckInDate(DateTime date) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt('lastCheckInDate', date.millisecondsSinceEpoch);
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

  Future<double?> getCachedTotalUpTraffic() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble('cachedTotalUpTraffic');
  }

  Future<void> setCachedTotalUpTraffic(double? value) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (value != null) {
      await preferences?.setDouble('cachedTotalUpTraffic', value);
    } else {
      await preferences?.remove('cachedTotalUpTraffic');
    }
  }

  Future<double?> getCachedTotalDownTraffic() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getDouble('cachedTotalDownTraffic');
  }

  Future<void> setCachedTotalDownTraffic(double? value) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (value != null) {
      await preferences?.setDouble('cachedTotalDownTraffic', value);
    } else {
      await preferences?.remove('cachedTotalDownTraffic');
    }
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
