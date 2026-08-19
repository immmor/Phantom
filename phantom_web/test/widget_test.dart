// WebView 壳的基本冒烟测试：验证错误页与引导逻辑可构建。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phantom_web/main.dart';

void main() {
  testWidgets('error view renders url and retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebShellErrorView(
            url: 'https://example.com',
            error: 'net::ERR_NAME_NOT_RESOLVED',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('页面加载失败'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);

    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });
}
