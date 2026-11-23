import 'package:sqflite/sqflite.dart';
import '../../domain/models/study_segment.dart';
import '../db/app_database.dart';

/// 学习片段统计结果包装类
class SegmentStats {
  const SegmentStats({
    required this.totalCount,
    required this.validTrainingCount,
    required this.coveredDays,
    this.earliest,
    this.latest,
  });
  final int totalCount;
  final int validTrainingCount;
  final int coveredDays;
  final DateTime? earliest;
  final DateTime? latest;
}

/// 学习片段数据仓库
/// 批量写入片段、查询可参与训练样本、统计样本概况、调整单个样本权重
class SegmentRepository {
  SegmentRepository(this._database);
  final AppDatabase _database;

  /// 批量插入学习片段，主键冲突直接覆盖
  Future<void> insertSegments(List<StudySegment> segments) async {
    if (segments.isEmpty) {
      return;
    }
    final db = await _database.database;
    final batch = db.batch();
    for (final segment in segments) {
      batch.insert(
        'study_segment',
        segment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取所有纳入训练的学习样本
  Future<List<StudySegment>> trainingSegments() async {
    final db = await _database.database;
    final rows = await db.query(
      'study_segment',
      where: "included_in_training = 1 AND scene IN ('study', 'classSession')",
      orderBy: 'started_at ASC',
    );
    return rows.map(StudySegment.fromMap).toList(growable: false);
  }

  /// 统计训练样本总量、时间跨度等指标
  Future<SegmentStats> trainingStats() async {
    final segments = await trainingSegments();
    if (segments.isEmpty) {
      return const SegmentStats(
        totalCount: 0,
        validTrainingCount: 0,
        coveredDays: 0,
      );
    }
    final earliest = segments.first.startedAt;
    final latest = segments.last.endedAt;
    final coveredDays = latest.difference(earliest).inDays + 1;
    return SegmentStats(
      totalCount: segments.length,
      validTrainingCount: segments.length,
      coveredDays: coveredDays,
      earliest: earliest,
      latest: latest,
    );
  }

  /// 对指定样本的权重乘以系数（用户否定该样本时降权）
  Future<void> reduceWeight(String segmentId, double multiplier) async {
    final db = await _database.database;
    await db.rawUpdate(
      'UPDATE study_segment SET sample_weight = sample_weight * ? WHERE id = ?',
      [multiplier, segmentId],
    );
  }
}



///管理 study_segment 表，
///批量存片段、拉取训练样本、统计数据、支持样本降权。