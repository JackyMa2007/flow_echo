import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// 本地SQLite数据库入口类
/// 管理flow_echo.db实例、数据库打开/关闭、清空数据、外键约束，建表逻辑交给migrations
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this.pathOverride})
    : _factory = factory ?? databaseFactory;

  ///数据库版本号，Beta V0.1初始版本1
  static const int version = 1;

  ///数据库文件名
  static const String fileName = 'flow_echo.db';

  final DatabaseFactory _factory;

  ///自定义数据库路径（用于调试)
  final String? pathOverride;
  Database? _database;

  ///判断数据库是否已经打开
  bool get isOpen => _database?.isOpen ?? false;

  ///获取数据库实例，单例复用；没打开则自动打开
  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) {
      return current;
    }

    final databasePath =
        pathOverride ?? path.join(await _factory.getDatabasesPath(), fileName);
    final opened = await _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: version,
        singleInstance: false,
        onConfigure: (db) async {
          //开启外键约束
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: createV1,
        onUpgrade: migrate,
      ),
    );
    _database = opened;
    return opened;
  }

  ///关闭数据库连接
  Future<void> close() async {
    final current = _database;
    _database = null;
    if (current != null && current.isOpen) {
      await current.close();
    }
  }

  ///清空全部业务数据，保留任务基础种子数据
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((transaction) async {
      const tables = [
        'notification_decision',
        'recovery_attempt',
        'correction',
        'baseline_state',
        'study_segment',
        'state_snapshot',
        'scene_session',
        'sensor_window',
        'settings',
      ];
      for (final table in tables) {
        await transaction.delete(table);
      }
      //重新初始化内置推荐任务
      await seedTasks(transaction);
    });
  }
}

///这是数据库管理类，负责打开、关闭数据库，
///支持一键清空业务数据并恢复初始任务数据。
