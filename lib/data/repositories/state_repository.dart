import 'package:sqflite/sqflite.dart';
import '../../domain/models/state_snapshot.dart';
import '../db/app_database.dart';

/// 心流状态快照数据仓库
/// 封装 state_snapshot 表的增查改操作，用于读取、保存状态计算结果，统计有记录的天数
class StateRepository {
  StateRepository(this._database);
  final AppDatabase _database;

  /// 插入或覆盖一条心流状态计算快照
  Future<void> insertSnapshot(StateSnapshot snapshot) async {
    final db = await _database.database;
    await db.insert(
      'state_snapshot',
      snapshot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取最新生成的一条状态快照，无数据返回null
  Future<StateSnapshot?> latestSnapshot() async {
    final db = await _database.database;
    final rows = await db.query(
      'state_snapshot',
      orderBy: 'calculated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return StateSnapshot.fromMap(rows.first);
  }

  /// 查询指定起止时间区间内所有状态快照，按计算时间升序排列
  Future<List<StateSnapshot>> snapshotsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'state_snapshot',
      where: 'calculated_at >= ? AND calculated_at <= ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'calculated_at ASC',
    );
    return rows.map(StateSnapshot.fromMap).toList(growable: false);
  }

  /// 将指定快照标记为已被用户手动修正
  Future<void> markCorrected(String snapshotId) async {
    final db = await _database.database;
    await db.update(
      'state_snapshot',
      {'corrected': 1},
      where: 'id = ?',
      whereArgs: [snapshotId],
    );
  }

  /// 统计时间段内，存在状态快照记录的不同日期总数
  Future<int> countDistinctDataDays(DateTime from, DateTime to) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT date(calculated_at / 1000, 'unixepoch', 'localtime'))
      AS day_count
      FROM state_snapshot
      WHERE calculated_at >= ? AND calculated_at <= ?
      ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (rows.first['day_count'] as int?) ?? 0;
  }
}




///这个仓库负责心流快照的存储、查询、标记修正和统计有数据的天数。