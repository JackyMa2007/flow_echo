import 'package:sqflite/sqflite.dart';

import '../../domain/models/baseline_state.dart';
import '../db/app_database.dart';

/// 负责读取和保存个人基线。
///
/// 基线相当于比较的尺子：同样心率80，对平时70的人偏高，对平时85的人并不高。
class BaselineRepository {
  BaselineRepository(this._database);

  final AppDatabase _database;

  /// 获取当前有效基线；第一次使用时自动创建并保存默认基线。
  Future<BaselineState> getActive({DateTime? now}) async {
    final db = await _database.database;
    final effectiveNow = now ?? DateTime.now();
    final rows = await db.query(
      'baseline_state',
      where: 'is_active = 1 AND (expires_at IS NULL OR expires_at > ?)',
      whereArgs: [effectiveNow.millisecondsSinceEpoch],
      orderBy: 'effective_at DESC',
      limit: 1,
    );

    // 已有有效基线时直接复用，不会每次启动都新建一条。
    if (rows.isNotEmpty) {
      return BaselineState.fromMap(rows.first);
    }

    final initial = BaselineState.initial(effectiveNow);
    await save(initial);
    return initial;
  }

  /// 按ID查看某条基线，主要用于测试和后续撤销校准。
  Future<BaselineState?> findById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'baseline_state',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return BaselineState.fromMap(rows.first);
  }

  /// 保存新基线，并保证数据库里同一时间只有一条激活基线。
  Future<void> save(BaselineState baseline) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      // 先把旧基线停用，再插入新基线，避免两个基线同时生效。
      await transaction.update('baseline_state', {
        'is_active': 0,
      }, where: 'is_active = 1');
      await transaction.insert(
        'baseline_state',
        baseline.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}
