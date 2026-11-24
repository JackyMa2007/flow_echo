import '../../core/constants.dart';
import '../../core/json_utils.dart';

/// 心流状态计算快照模型
/// 调用calc_mental_state算法后生成的结果快照，保存投入度、消耗度、象限、解释文案，UI展示的数据源
class StateSnapshot {
  const StateSnapshot({
    required this.id,
    required this.sceneSessionId,
    required this.calculatedAt,
    required this.investment,
    required this.depletion,
    required this.confidence,
    required this.quadrant,
    required this.evidence,
    required this.templateText,
    required this.displayText,
    this.ambiguityReason,
    this.corrected = false,
    this.modelVersion,
  });

  /// 快照唯一ID
  final String id;

  /// 归属的场景会话ID
  final String sceneSessionId;

  /// 算法计算完成时间
  final DateTime calculatedAt;

  /// 投入度 0~1
  final double investment;

  /// 消耗度 0~1
  final double depletion;

  /// 置信度 0~1，越低越模糊
  final double confidence;

  /// 判定象限：顺流/攻坚/空转/苦撑/模糊
  final Quadrant quadrant;

  /// 模糊原因，quadrant为模糊时才有值
  final AmbiguityReason? ambiguityReason;

  /// 判定依据证据包，存放算法判断的原始理由数据
  final Map<String, Object?> evidence;

  /// 原始文案模板（本地模板，云端润色前）
  final String templateText;

  /// 最终展示文案（云端润色后，断网则等于templateText）
  final String displayText;

  /// 是否被用户手动修正过
  final bool corrected;

  /// 算法/模型版本号
  final String? modelVersion;

  /// 转为数据库存储Map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'scene_session_id': sceneSessionId,
      'calculated_at': calculatedAt.millisecondsSinceEpoch,
      'investment': investment,
      'depletion': depletion,
      'confidence': confidence,
      'quadrant': quadrant.name,
      'ambiguity_reason': ambiguityReason?.name,
      'evidence_json': encodeObjectMap(evidence),
      'template_text': templateText,
      'display_text': displayText,
      'corrected': corrected ? 1 : 0,
      'model_version': modelVersion,
    };
  }

  /// 从数据库Map还原StateSnapshot对象
  factory StateSnapshot.fromMap(Map<String, Object?> map) {
    final reason = map['ambiguity_reason'] as String?;
    return StateSnapshot(
      id: map['id']! as String,
      sceneSessionId: map['scene_session_id']! as String,
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['calculated_at']! as int,
      ),
      investment: (map['investment']! as num).toDouble(),
      depletion: (map['depletion']! as num).toDouble(),
      confidence: (map['confidence']! as num).toDouble(),
      quadrant: Quadrant.values.byName(map['quadrant']! as String),
      ambiguityReason: reason == null
          ? null
          : AmbiguityReason.values.byName(reason),
      evidence: decodeObjectMap(map['evidence_json']),
      templateText: map['template_text']! as String,
      displayText: map['display_text']! as String,
      corrected: (map['corrected']! as int) == 1,
      modelVersion: map['model_version'] as String?,
    );
  }
}

///算法跑出来的【结果快照】，界面上的心流地图坐标、状态文字全部读这个模型；
///用户修正记录（Correction）也是关联这一条 snapshotId。
