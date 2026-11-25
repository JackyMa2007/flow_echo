import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_echo/application/home_live_controller.dart';
import 'package:flow_echo/application/scene_coordinator.dart';
import 'package:flow_echo/app.dart';
import 'package:flow_echo/data/db/app_database.dart';
import 'package:flow_echo/data/repositories/baseline_repository.dart';
import 'package:flow_echo/data/repositories/scene_session_repository.dart';
import 'package:flow_echo/domain/engine/feature_extractor.dart';
import 'package:flow_echo/domain/engine/state_engine.dart';
import 'package:flow_echo/providers/app_providers.dart';
import 'package:flow_echo/simulation/sensor_simulator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('显示心流回响基础骨架', (tester) async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    final sessionRepository = SceneSessionRepository(database);
    final controller = HomeLiveController(
      SensorSimulator(),
      BaselineRepository(database),
      const FeatureExtractor(),
      const StateEngine(),
      SceneCoordinator(sessionRepository),
      tickInterval: const Duration(hours: 1),
      initialSampleCount: 12,
    );
    await tester.runAsync(() => controller.start());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          homeLiveControllerProvider.overrideWithValue(controller),
        ],
        child: const FlowEchoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('心流回响'), findsOneWidget);
    expect(find.text('演示模拟数据，仅用于产品功能验证'), findsOneWidget);
    expect(find.text('当前场景'), findsOneWidget);
    expect(find.text('心流地图'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('指纹'), findsOneWidget);
    expect(find.text('回顾'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.runAsync(database.close);
  });
}
