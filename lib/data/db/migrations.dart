import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../../domain/models/task_item.dart';

/// 数据库迁移脚本V1
/// 定义全部数据表、索引，首次建库执行建表并初始化内置推荐任务；预留版本升级迁移入口
const List<String> v1Statements = [
  '''
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS sensor_window (
    id TEXT PRIMARY KEY,
    captured_at INTEGER NOT NULL,
    scene TEXT NOT NULL,
    heart_rate REAL NOT NULL,
    hrv REAL NOT NULL,
    sedentary_minutes REAL NOT NULL,
    unlock_count INTEGER NOT NULL,
    input_activity REAL NOT NULL,
    app_switch_count INTEGER NOT NULL,
    data_source TEXT NOT NULL,
    is_complete INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS scene_session (
    id TEXT PRIMARY KEY,
    scene TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    end_reason TEXT
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS state_snapshot (
    id TEXT PRIMARY KEY,
    scene_session_id TEXT NOT NULL,
    calculated_at INTEGER NOT NULL,
    investment REAL NOT NULL,
    depletion REAL NOT NULL,
    confidence REAL NOT NULL,
    quadrant TEXT NOT NULL,
    ambiguity_reason TEXT,
    evidence_json TEXT NOT NULL,
    template_text TEXT NOT NULL,
    display_text TEXT NOT NULL,
    corrected INTEGER NOT NULL DEFAULT 0,
    model_version TEXT
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS study_segment (
    id TEXT PRIMARY KEY,
    scene_session_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    scene TEXT NOT NULL,
    sample_weight REAL NOT NULL DEFAULT 1.0,
    label TEXT,
    feature_json TEXT NOT NULL,
    included_in_training INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS correction (
    id TEXT PRIMARY KEY,
    snapshot_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    old_investment REAL NOT NULL,
    old_depletion REAL NOT NULL,
    new_investment REAL NOT NULL,
    new_depletion REAL NOT NULL,
    old_quadrant TEXT NOT NULL,
    new_quadrant TEXT NOT NULL,
    before_baseline_json TEXT NOT NULL,
    after_baseline_json TEXT NOT NULL,
    affected_segment_id TEXT,
    created_at INTEGER NOT NULL,
    undone_at INTEGER
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS baseline_state (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    effective_at INTEGER NOT NULL,
    expires_at INTEGER,
    baseline_json TEXT NOT NULL,
    source TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS task_item (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    cognitive_load TEXT NOT NULL,
    suitable_quadrants TEXT NOT NULL,
    estimated_minutes INTEGER NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS notification_decision (
    id TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    snapshot_id TEXT NOT NULL,
    level TEXT NOT NULL,
    cost REAL NOT NULL,
    value REAL NOT NULL,
    budget_remaining INTEGER NOT NULL,
    queued INTEGER NOT NULL,
    reason TEXT NOT NULL,
    delivered_at INTEGER
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS recovery_attempt (
    id TEXT PRIMARY KEY,
    activity_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    completed_at INTEGER,
    before_score REAL,
    after_score REAL,
    succeeded INTEGER
  )
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_sensor_window_captured_at
  ON sensor_window(captured_at)
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_state_snapshot_calculated_at
  ON state_snapshot(calculated_at)
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_study_segment_started_at
  ON study_segment(started_at)
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_notification_decision_created_at
  ON notification_decision(created_at)
  ''',
];

///数据库版本1初始化：依次执行建表语句，完成后导入内置任务
Future<void> createV1(Database db, int version) async {
  for (final statement in v1Statements) {
    await db.execute(statement);
  }
  await seedTasks(db);
}

///版本升级迁移函数，当前是首个版本，后续迭代新增表/字段写在这里
Future<void> migrate(Database db, int oldVersion, int newVersion) async {
  // Version 1 is the first schema. Future migrations belong here.
}

///种子数据：批量插入初始推荐任务，冲突时跳过，保证重置数据后任务库还在
Future<void> seedTasks(DatabaseExecutor db) async {
  final nowTasks = <TaskItem>[
    const TaskItem(
      id: 'task_high_01',
      title: '完成一道综合推导题',
      cognitiveLoad: CognitiveLoad.high,
      suitableQuadrants: {Quadrant.flow},
      estimatedMinutes: 20,
    ),
    const TaskItem(
      id: 'task_high_02',
      title: '整理一章知识框架',
      cognitiveLoad: CognitiveLoad.high,
      suitableQuadrants: {Quadrant.flow},
      estimatedMinutes: 25,
    ),
    const TaskItem(
      id: 'task_high_03',
      title: '写一段证明或代码实现',
      cognitiveLoad: CognitiveLoad.high,
      suitableQuadrants: {Quadrant.flow, Quadrant.challenge},
      estimatedMinutes: 20,
    ),
    const TaskItem(
      id: 'task_medium_01',
      title: '订正 3 道错题',
      cognitiveLoad: CognitiveLoad.medium,
      suitableQuadrants: {Quadrant.challenge},
      estimatedMinutes: 10,
    ),
    const TaskItem(
      id: 'task_medium_02',
      title: '复述刚学过的概念',
      cognitiveLoad: CognitiveLoad.medium,
      suitableQuadrants: {Quadrant.flow, Quadrant.challenge},
      estimatedMinutes: 8,
    ),
    const TaskItem(
      id: 'task_medium_03',
      title: '整理今天的三条笔记',
      cognitiveLoad: CognitiveLoad.medium,
      suitableQuadrants: {Quadrant.challenge, Quadrant.idle},
      estimatedMinutes: 10,
    ),
    const TaskItem(
      id: 'task_low_01',
      title: '整理桌面和资料',
      cognitiveLoad: CognitiveLoad.low,
      suitableQuadrants: {Quadrant.idle},
      estimatedMinutes: 5,
    ),
    const TaskItem(
      id: 'task_low_02',
      title: '抄写下一阶段待办清单',
      cognitiveLoad: CognitiveLoad.low,
      suitableQuadrants: {Quadrant.idle},
      estimatedMinutes: 5,
    ),
    const TaskItem(
      id: 'task_low_03',
      title: '把资料按主题归档',
      cognitiveLoad: CognitiveLoad.low,
      suitableQuadrants: {Quadrant.idle},
      estimatedMinutes: 5,
    ),
    const TaskItem(
      id: 'task_low_04',
      title: '清理下载文件夹',
      cognitiveLoad: CognitiveLoad.low,
      suitableQuadrants: {Quadrant.idle},
      estimatedMinutes: 5,
    ),
    const TaskItem(
      id: 'task_low_05',
      title: '列出下一小步',
      cognitiveLoad: CognitiveLoad.low,
      suitableQuadrants: {Quadrant.idle, Quadrant.fuzzy},
      estimatedMinutes: 3,
    ),
    const TaskItem(
      id: 'task_low_06',
      title: '复习 5 个已有单词',
      cognitiveLoad: CognitiveLoad.low,
      suitableQuadrants: {Quadrant.challenge, Quadrant.idle},
      estimatedMinutes: 5,
    ),
  ];

  final batch = db.batch();
  for (final task in nowTasks) {
    batch.insert(
      'task_item',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  await batch.commit(noResult: true);
}

///数据库建表脚本，定义全部表结构、索引，首次创建数据库时自动建好表并预置推荐任务。
