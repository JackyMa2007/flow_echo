import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/scene_coordinator.dart';
import '../data/db/app_database.dart';
import '../data/repositories/baseline_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/scene_session_repository.dart';
import '../data/repositories/segment_repository.dart';
import '../data/repositories/state_repository.dart';
import '../data/repositories/task_repository.dart';
import '../domain/engine/feature_extractor.dart';
import '../domain/engine/state_engine.dart';
import '../domain/models/baseline_state.dart';
import '../simulation/sensor_simulator.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('databaseProvider must be overridden during startup.');
});

final stateRepositoryProvider = Provider<StateRepository>((ref) {
  return StateRepository(ref.watch(databaseProvider));
});

final segmentRepositoryProvider = Provider<SegmentRepository>((ref) {
  return SegmentRepository(ref.watch(databaseProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(databaseProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(databaseProvider));
});

final sceneSessionRepositoryProvider = Provider<SceneSessionRepository>((ref) {
  return SceneSessionRepository(ref.watch(databaseProvider));
});

/// 全局只创建一个协调器，保证当前场景不会因页面刷新而丢失。
final sceneCoordinatorProvider = Provider<SceneCoordinator>((ref) {
  return SceneCoordinator(ref.watch(sceneSessionRepositoryProvider));
});

final baselineRepositoryProvider = Provider<BaselineRepository>((ref) {
  return BaselineRepository(ref.watch(databaseProvider));
});

// 页面读取这个 Provider 时，会自动拿到当前基线；首次使用会创建默认基线。
final activeBaselineProvider = FutureProvider<BaselineState>((ref) {
  return ref.watch(baselineRepositoryProvider).getActive();
});

// 特征提取器不保存用户状态，可以安全复用同一个实例。
final featureExtractorProvider = Provider<FeatureExtractor>((ref) {
  return const FeatureExtractor();
});

// 状态判定引擎不保存数据，可以复用同一个无状态实例。
final stateEngineProvider = Provider<StateEngine>((ref) {
  return const StateEngine();
});

final sensorSimulatorProvider = Provider<SensorSimulator>((ref) {
  return SensorSimulator();
});
