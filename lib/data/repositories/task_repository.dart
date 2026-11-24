import '../../domain/models/task_item.dart';
import '../db/app_database.dart';

/// 推荐任务数据仓库
/// 封装task_item表操作：查询启用/全部任务、开关单个任务启用状态
class TaskRepository {
  TaskRepository(this._database);
  final AppDatabase _database;

  /// 获取所有启用的推荐任务，按预估时长、标题排序
  Future<List<TaskItem>> enabledTasks() async {
    final db = await _database.database;
    final rows = await db.query(
      'task_item',
      where: 'enabled = 1',
      orderBy: 'estimated_minutes ASC, title ASC',
    );
    return rows.map(TaskItem.fromMap).toList(growable: false);
  }

  /// 获取全部任务（包含已关闭），按预估时长、标题排序
  Future<List<TaskItem>> allTasks() async {
    final db = await _database.database;
    final rows = await db.query(
      'task_item',
      orderBy: 'estimated_minutes ASC, title ASC',
    );
    return rows.map(TaskItem.fromMap).toList(growable: false);
  }

  Future<TaskItem?> findById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'task_item',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TaskItem.fromMap(rows.first);
  }

  /// 修改指定任务的启用/关闭状态
  Future<void> setEnabled(String id, bool enabled) async {
    final db = await _database.database;
    await db.update(
      'task_item',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

///任务仓库，读取任务列表和控制任务是否参与推荐。
