import 'package:flow_echo/application/home_live_controller.dart';
import 'package:flow_echo/application/scene_coordinator.dart';
import 'package:flow_echo/core/constants.dart';
import 'package:flow_echo/data/db/app_database.dart';
import 'package:flow_echo/data/repositories/baseline_repository.dart';
import 'package:flow_echo/data/repositories/scene_session_repository.dart';
import 'package:flow_echo/data/repositories/state_repository.dart';
import 'package:flow_echo/domain/engine/feature_extractor.dart';
import 'package:flow_echo/domain/engine/state_engine.dart';
import 'package:flow_echo/simulation/sensor_simulator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SceneSessionRepository sessionRepository;
  late StateRepository stateRepository;
  late HomeLiveController controller;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    sessionRepository = SceneSessionRepository(database);
    stateRepository = StateRepository(database);
    controller = HomeLiveController(
      SensorSimulator(),
      BaselineRepository(database),
      const FeatureExtractor(),
      const StateEngine(),
      SceneCoordinator(sessionRepository),
      tickInterval: const Duration(hours: 1),
      initialSampleCount: 12,
    );
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  test('首页控制器启动后生成默认自习场景和状态', () async {
    await controller.start();

    expect(controller.state, isNotNull);
    expect(controller.state!.session.scene, SceneType.study);
    expect(controller.state!.evidence.sampleCount, 12);
    expect(controller.state!.evaluation.investment, inInclusiveRange(0, 1));
    expect(controller.state!.evaluation.depletion, inInclusiveRange(0, 1));
  });

  test('首页切换场景会结束旧场景并生成新状态', () async {
    await controller.start();
    final oldSessionId = controller.state!.session.id;

    await controller.switchScene(SceneType.classSession);

    final oldSession = await sessionRepository.findById(oldSessionId);
    final active = await sessionRepository.findActiveSession();
    final snapshot = await stateRepository.latestSnapshot();

    expect(controller.state!.session.scene, SceneType.classSession);
    expect(oldSession!.endedAt, isNotNull);
    expect(oldSession.endReason, SceneEndReason.sceneSwitch.value);
    expect(active!.id, controller.state!.session.id);
    expect(snapshot!.sceneSessionId, oldSessionId);
  });
}
