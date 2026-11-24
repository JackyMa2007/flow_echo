import '../../core/constants.dart';

/// 场景会话模型
/// 用户切换场景（自习/上课/休息/娱乐）时开启一条会话，切换新场景就结束当前会话
class SceneSession {
  const SceneSession({
    required this.id,
    required this.scene,
    required this.startedAt,
    this.endedAt,
    this.endReason,
  });

  /// 会话唯一ID
  final String id;

  /// 会话场景类型
  final SceneType scene;

  /// 会话开始时间
  final DateTime startedAt;

  /// 会话结束时间，为空代表会话正在进行中
  final DateTime? endedAt;

  /// 结束原因：切换场景 / 手动结束
  final String? endReason;

  /// 计算会话时长：已结束就用结束时间，未结束就用当前时间
  Duration durationAt(DateTime now) {
    return (endedAt ?? now).difference(startedAt);
  }

  /// 复制并修改部分字段（用来关闭会话、填充endedAt和endReason）
  SceneSession copyWith({DateTime? endedAt, String? endReason}) {
    return SceneSession(
      id: id,
      scene: scene,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      endReason: endReason ?? this.endReason,
    );
  }

  /// 转为数据库存储Map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'scene': scene.name,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'end_reason': endReason,
    };
  }

  /// 从数据库Map还原SceneSession对象
  factory SceneSession.fromMap(Map<String, Object?> map) {
    final endedAt = map['ended_at'] as int?;
    return SceneSession(
      id: map['id']! as String,
      scene: SceneType.values.byName(map['scene']! as String),
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at']! as int),
      endedAt: endedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endedAt),
      endReason: map['end_reason'] as String?,
    );
  }
}

///对应 Beta 第一条需求 —— 切换场景立刻结束当前片段结算，
///这个就是用来记录每一段场景周期。
