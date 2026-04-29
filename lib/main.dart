import 'dart:async';
import 'dart:io';

import 'package:fl_clash/application.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/pages/login.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final version = await system.version;
    final container = await globalState.init(version);
    HttpOverrides.global = FlClashHttpOverrides();

    final lastLogin = await preferences.getLastLoginTime();
    final isLoggedIn = lastLogin != null &&
        DateTime.now().difference(lastLogin).inHours < 24;

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: isLoggedIn ? const Application() : const LoginPage(),
        ),
      ),
    );
  } catch (e, s) {
    return runApp(
      MaterialApp(
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
