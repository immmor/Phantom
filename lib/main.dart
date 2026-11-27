import 'dart:async';
import 'dart:io';

import 'package:fl_clash/application.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final version = await system.version;
    final container = await globalState.init(version);
    HttpOverrides.global = FlClashHttpOverrides();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: HiddenBarScrollBehavior(),
          home: const Application(),
        ),
      ),
    );
  } catch (e, s) {
    return runApp(
      MaterialApp(
        scrollBehavior: HiddenBarScrollBehavior(),
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
