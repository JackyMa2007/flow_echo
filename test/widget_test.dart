import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_echo/app.dart';

void main() {
  testWidgets('显示心流回响基础骨架', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlowEchoApp()));
    await tester.pumpAndSettle();

    expect(find.text('心流回响'), findsOneWidget);
    expect(find.text('演示模拟数据，仅用于产品功能验证'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('指纹'), findsOneWidget);
    expect(find.text('回顾'), findsOneWidget);
  });
}
