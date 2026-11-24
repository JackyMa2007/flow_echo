import '../../core/constants.dart';
import 'evidence.dart';

/// StateEngine 的最终输出。
///
/// quadrant 是给用户看的状态，evidence 则保留“为什么这样判断”的全部依据。
class StateEvaluation {
  const StateEvaluation({
    required this.quadrant,
    required this.investment,
    required this.depletion,
    required this.confidence,
    required this.evidence,
    this.ambiguityReason,
  });

  final Quadrant quadrant;
  final double investment;
  final double depletion;
  final double confidence;
  final Evidence evidence;
  final AmbiguityReason? ambiguityReason;

  bool get isHighInvestment => investment >= investmentHighThreshold;
  bool get isHighDepletion => depletion >= depletionHighThreshold;

  /// 模糊状态必须带可读原因，不能只显示“模糊”两个字。
  String? get ambiguityText => ambiguityReason?.label;

  Map<String, Object?> toJson() {
    return {
      'quadrant': quadrant.name,
      'investment': investment,
      'depletion': depletion,
      'confidence': confidence,
      'ambiguityReason': ambiguityReason?.name,
      'evidence': evidence.toJson(),
    };
  }
}
