import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/segment_repository.dart';
import '../data/repositories/state_repository.dart';
import '../data/repositories/task_repository.dart';

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
