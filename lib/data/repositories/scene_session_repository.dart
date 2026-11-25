import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../../domain/models/scene_session.dart';
import '../../domain/models/state_snapshot.dart';
import '../db/app_database.dart';

/// 负责场景会话的读取、开始、结束和原子切换。
class SceneSessionRepository {
  SceneSessionRepository(this._database);

  final AppDatabase _database;

  /// 新开始一个场景。
  Future<void> insertSession(SceneSession session) async {
    final db = await _database.database;
    await db.insert(
      'scene_session',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查找当前还没有结束的场景。
  Future<SceneSession?> findActiveSession() async {
    final db = await _database.database;
    final rows = await db.query(
      'scene_session',
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }
    return SceneSession.fromMap(rows.first);
  }

  /// 按 ID 查询一条场景会话。
  Future<SceneSession?> findById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'scene_session',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }
    return SceneSession.fromMap(rows.first);
  }

  /// 单独结束场景，例如暂停应用或用户手动停止。
  Future<void> completeSession({
    required String id,
    required DateTime endedAt,
    required SceneEndReason reason,
  }) async {
    final db = await _database.database;
    await db.update(
      'scene_session',
      {'ended_at': endedAt.millisecondsSinceEpoch, 'end_reason': reason.value},
      where: 'id = ? AND ended_at IS NULL',
      whereArgs: [id],
    );
  }

  /// 切换场景：结束旧场景、保存最后快照、创建新场景。
  ///
  /// 三件事放在同一个事务中，任何一步失败都会整体回滚。
  Future<void> switchScene({
    required SceneSession current,
    required DateTime endedAt,
    required SceneSession next,
    required SceneEndReason reason,
    StateSnapshot? finalSnapshot,
  }) async {
    final db = await _database.database;

    await db.transaction((transaction) async {
      // 1. 立即结束旧场景。
      await transaction.update(
        'scene_session',
        {
          'ended_at': endedAt.millisecondsSinceEpoch,
          'end_reason': reason.value,
        },
        where: 'id = ? AND ended_at IS NULL',
        whereArgs: [current.id],
      );

      // 2. 保存切换前最后一次状态判定。
      if (finalSnapshot != null) {
        await transaction.insert(
          'state_snapshot',
          finalSnapshot.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 3. 创建新场景。
      await transaction.insert(
        'scene_session',
        next.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}
