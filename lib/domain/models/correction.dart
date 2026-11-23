import '../../core/constants.dart';
import '../../core/json_utils.dart';

/// 用户手动修正记录模型
/// 记录用户在【心流地图】拖拽修改投入度/消耗度坐标的操作，用于校准基线、留存修正日志
class Correction {
  const Correction({
    required this.id,
    required this.snapshotId,
    required this.reason,
    required this.oldInvestment,
    required this.oldDepletion,
    required this.newInvestment,
    required this.newDepletion,
    required this.oldQuadrant,
    required this.newQuadrant,
    required this.beforeBaseline,
    required this.afterBaseline,
    required this.createdAt,
    this.affectedSegmentId,
    this.undoneAt,
  });

/// 本条修正记录唯一ID
  final String id;
  /// 对应当时生理快照的id
  final String snapshotId;
  /// 修正原因：状态错 / 场景错 / 数据不准
  final CorrectionReason reason;
  /// 修改前投入度
  final double oldInvestment;
  /// 修改前消耗度
  final double oldDepletion;
  /// 修改后投入度
  final double newInvestment;
  /// 修改后消耗度
  final double newDepletion;
  /// 修改前象限
  final Quadrant oldQuadrant;
  /// 修改后象限
  final Quadrant newQuadrant;
  /// 修正操作之前的基线快照
  final Map<String, Object?> beforeBaseline;
  /// 修正操作生成的新基线
  final Map<String, Object?> afterBaseline;
  /// 本次修正影响的学习片段id（可选）
  final String? affectedSegmentId;
  /// 修正创建时间
  final DateTime createdAt;
  /// 撤销时间；不为空代表这条修正已经被撤销
  final DateTime? undoneAt;

  ///转为数据库存储Map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'snapshot_id': snapshotId,
      'reason': reason.name,
      'old_investment': oldInvestment,
      'old_depletion': oldDepletion,
      'new_investment': newInvestment,
      'new_depletion': newDepletion,
      'old_quadrant': oldQuadrant.name,
      'new_quadrant': newQuadrant.name,
      'before_baseline_json': encodeObjectMap(beforeBaseline),
      'after_baseline_json': encodeObjectMap(afterBaseline),
      'affected_segment_id': affectedSegmentId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'undone_at': undoneAt?.millisecondsSinceEpoch,
    };
  }

///从数据库Map还原Correction对象
  factory Correction.fromMap(Map<String, Object?> map) {
    final undoneAt = map['undone_at'] as int?;
    return Correction(
      id: map['id']! as String,
      snapshotId: map['snapshot_id']! as String,
      reason: CorrectionReason.values.byName(map['reason']! as String),
      oldInvestment: (map['old_investment']! as num).toDouble(),
      oldDepletion: (map['old_depletion']! as num).toDouble(),
      newInvestment: (map['new_investment']! as num).toDouble(),
      newDepletion: (map['new_depletion']! as num).toDouble(),
      oldQuadrant: Quadrant.values.byName(map['old_quadrant']! as String),
      newQuadrant: Quadrant.values.byName(map['new_quadrant']! as String),
      beforeBaseline: decodeObjectMap(map['before_baseline_json']),
      afterBaseline: decodeObjectMap(map['after_baseline_json']),
      affectedSegmentId: map['affected_segment_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      undoneAt: undoneAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(undoneAt),
    );
  }
}

///用户拖拽心流地图改坐标时，存一条修正记录，同时保存改之前、改之后的基线，
///支持撤销修正，也是个人校准数据集来源。