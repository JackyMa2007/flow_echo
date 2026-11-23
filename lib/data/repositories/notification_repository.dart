import 'package:sqflite/sqflite.dart';
import '../../domain/models/notification_decision.dart';
import '../db/app_database.dart';

/// 提醒决策数据仓库
/// 封装notification_decision表操作：保存提醒决策、按时间区间查询提醒记录
class NotificationRepository {
  NotificationRepository(this._database);
  final AppDatabase _database;

  /// 保存一条提醒决策记录，主键冲突时覆盖旧记录
  Future<void> saveDecision(NotificationDecision decision) async {
    final db = await _database.database;
    await db.insert(
      'notification_decision',
      decision.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查询起止时间范围内所有提醒决策，按时间倒序返回
  Future<List<NotificationDecision>> decisionsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'notification_decision',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
    return rows.map(NotificationDecision.fromMap).toList(growable: false);
  }
}



///负责提醒决策表的写入和时间段查询，用来管控每日提醒额度、查看历史提醒。