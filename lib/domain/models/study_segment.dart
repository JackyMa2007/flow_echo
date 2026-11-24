import '../../core/constants.dart';
import '../../core/json_utils.dart';

/// 学习片段模型
/// 最小20分钟切分的样本单元，是后续指纹、训练数据集的基础样本；娱乐场景样本默认不参与训练
class StudySegment {
  const StudySegment({
    required this.id,
    required this.sceneSessionId,
    required this.startedAt,
    required this.endedAt,
    required this.scene,
    this.sampleWeight = 1.0,
    this.label,
    this.features = const <String, Object?>{},
    this.includedInTraining = true,
  });

  /// 片段唯一ID
  final String id;

  /// 归属场景会话ID
  final String sceneSessionId;

  /// 片段开始时间
  final DateTime startedAt;

  /// 片段结束时间
  final DateTime endedAt;

  /// 本片段场景标签
  final SceneType scene;

  /// 样本权重，用户校准过的样本权重会更高
  final double sampleWeight;

  /// 人工标签（预留）
  final String? label;

  /// 特征包，汇总这段时间内提取的统计特征
  final Map<String, Object?> features;

  /// 是否纳入指纹/训练集；娱乐场景标记为false，不参与推理训练
  final bool includedInTraining;

  /// 转为数据库存储Map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'scene_session_id': sceneSessionId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt.millisecondsSinceEpoch,
      'scene': scene.name,
      'sample_weight': sampleWeight,
      'label': label,
      'feature_json': encodeObjectMap(features),
      'included_in_training': includedInTraining ? 1 : 0,
    };
  }

  /// 从数据库Map还原StudySegment对象
  factory StudySegment.fromMap(Map<String, Object?> map) {
    return StudySegment(
      id: map['id']! as String,
      sceneSessionId: map['scene_session_id']! as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at']! as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at']! as int),
      scene: SceneType.values.byName(map['scene']! as String),
      sampleWeight: (map['sample_weight']! as num).toDouble(),
      label: map['label'] as String?,
      features: decodeObjectMap(map['feature_json']),
      includedInTraining: (map['included_in_training']! as int) == 1,
    );
  }
}

///Beta 里规定的 20 分钟最小样本块，
///所有的算法学习、指纹生成都是基于这个片段。
