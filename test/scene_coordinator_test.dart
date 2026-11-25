import 'package:flow_echo/application/scene_coordinator.dart';
import 'package:flow_echo/core/constants.dart';
import 'package:flow_echo/data/db/app_database.dart';
import 'package:flow_echo/data/repositories/scene_session_repository.dart';
import 'package:flow_echo/data/repositories/state_repository.dart';
import 'package:flow_echo/domain/engine/evidence.dart';
import 'package:flow_echo/domain/engine/state_evaluation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SceneSessionRepository sessionRepository;
  late StateRepository stateRepository;
  late SceneCoordinator coordinator;

  final startedAt = DateTime(2026, 11, 25, 9);

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    sessionRepository = SceneSessionRepository(database);
    stateRepository = StateRepository(database);
    coordinator = SceneCoordinator(sessionRepository);
  });

  tearDown(() async {
    await database.close();
  });

  Evidence buildEvidence() {
    return Evidence(
      heartRate: 78,
      baselineHeartRate: 72,
      heartRateZ: 0.75,
      hrv: 55,
      baselineHrv: 55,
      hrvDrop: 0,
      sedentaryMinutes: 20,
      sedentaryScore: 0,
      inputActivity: 0.75,
      inputScore: 1,
      unlockScore: 0,
      switchPenalty: 0,
      continuityScore: 0.8,
      continuousMinutes: 32,
      sceneRelevance: 1,
      investment: 0.78,
      depletion: 0.25,
      confidence: 0.85,
      sampleCount: 12,
      hasCompleteData: true,
      hasLargeGap: false,
      idleTripleSatisfied: false,
    );
  }

  StateEvaluation buildEvaluation({
    Quadrant quadrant = Quadrant.flow,
    AmbiguityReason? ambiguityReason,
  }) {
    return StateEvaluation(
      quadrant: quadrant,
      investment: 0.78,
      depletion: 0.25,
      confidence: 0.85,
      investmentThreshold: investmentHighThreshold,
      depletionThreshold: depletionHighThreshold,
      evidence: buildEvidence(),
      ambiguityReason: ambiguityReason,
    );
  }

  test('开始场景后数据库存在未结束记录', () async {
    final started = await coordinator.startScene(
      SceneType.study,
      startedAt: startedAt,
    );
    final active = await sessionRepository.findActiveSession();

    expect(started.scene, SceneType.study);
    expect(active, isNotNull);
    expect(active!.id, started.id);
    expect(active.endedAt, isNull);
  });

  test('切换场景立即结束旧场景并开始新场景', () async {
    final oldSession = await coordinator.startScene(
      SceneType.study,
      startedAt: startedAt,
    );
    final switchedAt = startedAt.add(const Duration(minutes: 30));

    final newSession = await coordinator.switchScene(
      SceneType.classSession,
      switchedAt: switchedAt,
    );
    final restoredOld = await sessionRepository.findById(oldSession.id);
    final active = await sessionRepository.findActiveSession();

    expect(restoredOld!.endedAt, switchedAt);
    expect(restoredOld.endReason, SceneEndReason.sceneSwitch.value);
    expect(active!.id, newSession.id);
    expect(active.scene, SceneType.classSession);
    expect(active.endedAt, isNull);
  });

  test('切换前的最新状态会保存为旧场景最后快照', () async {
    final oldSession = await coordinator.startScene(
      SceneType.study,
      startedAt: startedAt,
    );
    coordinator.updateEvaluation(buildEvaluation());

    await coordinator.switchScene(
      SceneType.classSession,
      switchedAt: startedAt.add(const Duration(minutes: 25)),
    );
    final snapshot = await stateRepository.latestSnapshot();

    expect(snapshot, isNotNull);
    expect(snapshot!.sceneSessionId, oldSession.id);
    expect(snapshot.quadrant, Quadrant.flow);
    expect(snapshot.displayText, '顺流');
  });

  test('重复选择当前场景不会创建重复记录', () async {
    final current = await coordinator.startScene(
      SceneType.study,
      startedAt: startedAt,
    );
    final returned = await coordinator.switchScene(
      SceneType.study,
      switchedAt: startedAt.add(const Duration(minutes: 5)),
    );
    final db = await database.database;
    final rows = await db.query('scene_session');

    expect(returned.id, current.id);
    expect(rows, hasLength(1));
  });

  test('可以从数据库恢复尚未结束的场景', () async {
    final started = await coordinator.startScene(
      SceneType.rest,
      startedAt: startedAt,
    );
    final restoredCoordinator = SceneCoordinator(sessionRepository);

    final restored = await restoredCoordinator.restoreActiveSession();

    expect(restored, isNotNull);
    expect(restored!.id, started.id);
    expect(restored.scene, SceneType.rest);
  });

  test('手动结束后不再存在活动场景', () async {
    final started = await coordinator.startScene(
      SceneType.study,
      startedAt: startedAt,
    );
    final endedAt = startedAt.add(const Duration(minutes: 15));

    await coordinator.stopScene(endedAt: endedAt);
    final restored = await sessionRepository.findById(started.id);

    expect(restored!.endedAt, endedAt);
    expect(restored.endReason, SceneEndReason.manualStop.value);
    expect(await sessionRepository.findActiveSession(), isNull);
  });

  test('模糊状态快照会包含具体模糊原因', () async {
    await coordinator.startScene(SceneType.study, startedAt: startedAt);
    coordinator.updateEvaluation(
      buildEvaluation(
        quadrant: Quadrant.fuzzy,
        ambiguityReason: AmbiguityReason.nearBoundary,
      ),
    );

    await coordinator.switchScene(
      SceneType.classSession,
      switchedAt: startedAt.add(const Duration(minutes: 20)),
    );
    final snapshot = await stateRepository.latestSnapshot();

    expect(snapshot, isNotNull);
    expect(snapshot!.ambiguityReason, AmbiguityReason.nearBoundary);
    expect(snapshot.displayText, contains('坐标处于象限边界'));
  });

  test('快照写入失败时整个场景切换事务回滚', () async {
    final oldSession = await coordinator.startScene(
      SceneType.study,
      startedAt: startedAt,
    );
    coordinator.updateEvaluation(buildEvaluation());
    final db = await database.database;
    await db.execute('''
      CREATE TRIGGER force_snapshot_failure
      BEFORE INSERT ON state_snapshot
      BEGIN
        SELECT RAISE(ABORT, 'forced snapshot failure');
      END
    ''');

    await expectLater(
      coordinator.switchScene(
        SceneType.classSession,
        switchedAt: startedAt.add(const Duration(minutes: 30)),
      ),
      throwsA(anything),
    );

    final restoredOld = await sessionRepository.findById(oldSession.id);
    final active = await sessionRepository.findActiveSession();

    expect(restoredOld!.endedAt, isNull);
    expect(active!.id, oldSession.id);
    expect((await db.query('scene_session')), hasLength(1));
  });
}
