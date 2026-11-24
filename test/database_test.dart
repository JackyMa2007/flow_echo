import 'package:flow_echo/core/constants.dart';
import 'package:flow_echo/data/db/app_database.dart';
import 'package:flow_echo/data/repositories/correction_repository.dart';
import 'package:flow_echo/data/repositories/notification_repository.dart';
import 'package:flow_echo/data/repositories/segment_repository.dart';
import 'package:flow_echo/data/repositories/state_repository.dart';
import 'package:flow_echo/data/repositories/task_repository.dart';
import 'package:flow_echo/domain/models/correction.dart';
import 'package:flow_echo/domain/models/notification_decision.dart';
import 'package:flow_echo/domain/models/state_snapshot.dart';
import 'package:flow_echo/domain/models/study_segment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late TaskRepository taskRepository;
  late StateRepository stateRepository;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    taskRepository = TaskRepository(database);
    stateRepository = StateRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('创建全部业务表并写入任务种子', () async {
    final db = await database.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tableNames = rows.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll([
        'settings',
        'sensor_window',
        'scene_session',
        'state_snapshot',
        'study_segment',
        'correction',
        'baseline_state',
        'task_item',
        'notification_decision',
        'recovery_attempt',
      ]),
    );

    final tasks = await taskRepository.enabledTasks();
    expect(tasks, hasLength(12));
    expect(
      tasks.map((task) => task.cognitiveLoad).toSet(),
      containsAll(CognitiveLoad.values),
    );
  });

  test('状态快照可以写入并读回', () async {
    final now = DateTime(2026, 11, 23, 9, 30);
    final snapshot = StateSnapshot(
      id: 'snapshot-1',
      sceneSessionId: 'session-1',
      calculatedAt: now,
      investment: 0.72,
      depletion: 0.31,
      confidence: 0.81,
      quadrant: Quadrant.flow,
      evidence: const {'heartRate': 75, 'inputActivity': 0.63},
      templateText: '当前处于顺流。',
      displayText: '当前处于顺流。',
    );

    await stateRepository.insertSnapshot(snapshot);
    final restored = await stateRepository.latestSnapshot();

    expect(restored, isNotNull);
    expect(restored!.id, snapshot.id);
    expect(restored.quadrant, Quadrant.flow);
    expect(restored.evidence['heartRate'], 75);
  });

  test('清空业务数据后保留任务种子', () async {
    final now = DateTime(2026, 11, 23, 10);
    await stateRepository.insertSnapshot(
      StateSnapshot(
        id: 'snapshot-2',
        sceneSessionId: 'session-2',
        calculatedAt: now,
        investment: 0.2,
        depletion: 0.3,
        confidence: 0.2,
        quadrant: Quadrant.fuzzy,
        ambiguityReason: AmbiguityReason.insufficientData,
        evidence: const {'sampleCount': 3},
        templateText: '数据量不足。',
        displayText: '数据量不足。',
      ),
    );

    await database.clearAllData();

    expect(await stateRepository.latestSnapshot(), isNull);
    expect(await taskRepository.enabledTasks(), hasLength(12));
  });

  test('五类 Repository 都可以按 ID 写入和查询', () async {
    final now = DateTime(2026, 11, 24, 9);
    final segmentRepository = SegmentRepository(database);
    final correctionRepository = CorrectionRepository(database);
    final notificationRepository = NotificationRepository(database);

    final snapshot = StateSnapshot(
      id: 'snapshot-by-id',
      sceneSessionId: 'session-by-id',
      calculatedAt: now,
      investment: 0.66,
      depletion: 0.42,
      confidence: 0.75,
      quadrant: Quadrant.flow,
      evidence: const {'sampleCount': 12},
      templateText: '当前处于顺流。',
      displayText: '当前处于顺流。',
    );
    await stateRepository.insertSnapshot(snapshot);

    final segment = StudySegment(
      id: 'segment-by-id',
      sceneSessionId: 'session-by-id',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 20)),
      scene: SceneType.study,
      features: const {'timeOfDay': 9},
    );
    await segmentRepository.insertSegments([segment]);

    final correction = Correction(
      id: 'correction-by-id',
      snapshotId: snapshot.id,
      reason: CorrectionReason.wrongState,
      oldInvestment: 0.66,
      oldDepletion: 0.42,
      newInvestment: 0.5,
      newDepletion: 0.5,
      oldQuadrant: Quadrant.flow,
      newQuadrant: Quadrant.fuzzy,
      beforeBaseline: const {'heartRate': 72},
      afterBaseline: const {'heartRate': 74},
      affectedSegmentId: segment.id,
      createdAt: now,
    );
    await correctionRepository.insertCorrection(correction);

    final decision = NotificationDecision(
      id: 'decision-by-id',
      createdAt: now,
      snapshotId: snapshot.id,
      level: NotificationLevel.l2,
      cost: 0.4,
      value: 0.7,
      budgetRemaining: 2,
      queued: false,
      reason: '信息价值高于打扰代价',
    );
    await notificationRepository.saveDecision(decision);

    expect(
      (await stateRepository.findById(snapshot.id))?.quadrant,
      Quadrant.flow,
    );
    expect(
      (await segmentRepository.findById(segment.id))?.scene,
      SceneType.study,
    );
    expect(
      (await correctionRepository.findById(correction.id))?.reason,
      CorrectionReason.wrongState,
    );
    expect((await taskRepository.findById('task_high_01'))?.title, '完成一道综合推导题');
    expect(
      (await notificationRepository.findById(decision.id))?.level,
      NotificationLevel.l2,
    );
  });
}
