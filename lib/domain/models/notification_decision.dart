import '../../core/constants.dart';

/// 提醒决策记录模型
/// 算法判断是否推送恢复提醒时生成这条记录，管理每日提醒额度、排队与下发状态
class NotificationDecision {
  const NotificationDecision({
    required this.id,
    required this.createdAt,
    required this.snapshotId,
    required this.level,
    required this.cost,
    required this.value,
    required this.budgetRemaining,
    required this.queued,
    required this.reason,
    this.deliveredAt,
  });

  /// 决策记录唯一ID
  final String id;
  /// 决策生成时间
  final DateTime createdAt;
  /// 关联的生理快照ID
  final String snapshotId;
  /// 提醒等级 l0~l3
  final NotificationLevel level;
  /// 消耗本次提醒额度
  final double cost;
  /// 本次提醒预期收益（恢复价值）
  final double value;
  /// 决策之后剩余可用提醒次数
  final int budgetRemaining;
  /// 是否进入等待队列，暂不下发
  final bool queued;
  /// 触发提醒的原因文本
  final String reason;
  /// 提醒实际推送成功时间；为空代表还没推送
  final DateTime? deliveredAt;

///转为数据库储存Map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at': createdAt.millisecondsSinceEpoch,
      'snapshot_id': snapshotId,
      'level': level.name,
      'cost': cost,
      'value': value,
      'budget_remaining': budgetRemaining,
      'queued': queued ? 1 : 0,
      'reason': reason,
      'delivered_at': deliveredAt?.millisecondsSinceEpoch,
    };
  }

///从数据库Map还原NotificationDecision对象
  factory NotificationDecision.fromMap(Map<String, Object?> map) {
    final deliveredAt = map['delivered_at'] as int?;
    return NotificationDecision(
      id: map['id']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      snapshotId: map['snapshot_id']! as String,
      level: NotificationLevel.values.byName(map['level']! as String),
      cost: (map['cost']! as num).toDouble(),
      value: (map['value']! as num).toDouble(),
      budgetRemaining: map['budget_remaining']! as int,
      queued: (map['queued']! as int) == 1,
      reason: map['reason']! as String,
      deliveredAt: deliveredAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deliveredAt),
    );
  }
}


///用来控制你 Beta 里「一天最多 3 次恢复提醒」的额度管理，
///记录每一次算法要不要弹提醒、有没有真正发出去。