import '../../domain/models/correction.dart';
import '../db/app_database.dart';

/// Correction数据仓库
/// 封装correction表的数据库操作：新增修正记录、按起始时间查询历史修正记录
class CorrectionRepository {
  CorrectionRepository(this._database);
  final AppDatabase _database;

  /// 插入一条用户手动修正快照的记录
  Future<void> insertCorrection(Correction correction) async {
    final db = await _database.database;
    await db.insert('correction', correction.toMap());
  }

  /// 查询指定时间之后所有修正记录，按时间倒序
  Future<List<Correction>> correctionsSince(DateTime from) async {
    final db = await _database.database;
    final rows = await db.query(
      'correction',
      where: 'created_at >= ?',
      whereArgs: [from.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
    return rows.map(Correction.fromMap).toList(growable: false);
  }
}


///专门封装 correction 表的新增和按时间查询操作，隔离业务代码和 SQL。