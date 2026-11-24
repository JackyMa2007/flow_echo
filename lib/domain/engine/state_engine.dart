import '../../core/constants.dart';
import '../models/baseline_state.dart';
import 'evidence.dart';
import 'state_evaluation.dart';

/// 根据 FeatureExtractor 产出的 Evidence 做最终五状态判定。
///
/// 这里只读 Evidence 和 BaselineState，不访问数据库，也不生成界面文案。
class StateEngine {
  const StateEngine();

  StateEvaluation evaluate({
    required Evidence evidence,
    required BaselineState baseline,
  }) {
    // 没有完整数据或样本太少时，任何象限结论都不可靠。
    if (!evidence.hasCompleteData ||
        evidence.sampleCount < minimumFeatureSamples) {
      return _fuzzy(evidence, AmbiguityReason.insufficientData);
    }

    if (evidence.hasLargeGap) {
      return _fuzzy(evidence, AmbiguityReason.insufficientData);
    }

    if (evidence.confidence < minimumStateConfidence) {
      return _fuzzy(evidence, AmbiguityReason.featureConflict);
    }

    final heartRateAboveBaseline =
        evidence.heartRate > baseline.heartRate + idleHeartRateRise;
    final inputBelowIdleThreshold = evidence.inputActivity < idleInputThreshold;
    final sedentaryLongEnough =
        evidence.sedentaryMinutes >= idleSedentaryMinutes;
    // 空转需要三项同时成立，成立后优先返回，不进入普通四象限判断。
    if (evidence.idleTripleSatisfied) {
      return _result(evidence, Quadrant.idle);
    }

    // 久坐很长，并且心率或输入只有一项异常时，两类证据互相矛盾。
    if (sedentaryLongEnough &&
        (inputBelowIdleThreshold || heartRateAboveBaseline)) {
      return _fuzzy(evidence, AmbiguityReason.featureConflict);
    }

    // 坐标落在0.45~0.55附近时，不强行归入某一象限。
    final investmentNearBoundary =
        evidence.investment >= fuzzyLower && evidence.investment <= fuzzyUpper;
    final depletionNearBoundary =
        evidence.depletion >= fuzzyLower && evidence.depletion <= fuzzyUpper;
    if (investmentNearBoundary || depletionNearBoundary) {
      return _fuzzy(evidence, AmbiguityReason.nearBoundary);
    }

    final highInvestment = evidence.investment >= baseline.investmentThreshold;
    final highDepletion = evidence.depletion >= baseline.depletionThreshold;

    if (highInvestment && !highDepletion) {
      return _result(evidence, Quadrant.flow);
    }
    if (highInvestment && highDepletion) {
      return _result(evidence, Quadrant.challenge);
    }
    if (!highInvestment && highDepletion) {
      return _result(evidence, Quadrant.struggle);
    }

    // 低投入低消耗只有在空转三条件成立时才是空转，否则只能返回模糊。
    return _fuzzy(evidence, AmbiguityReason.idleConditionsNotMet);
  }

  StateEvaluation _result(Evidence evidence, Quadrant quadrant) {
    return StateEvaluation(
      quadrant: quadrant,
      investment: evidence.investment,
      depletion: evidence.depletion,
      confidence: evidence.confidence,
      evidence: evidence,
    );
  }

  StateEvaluation _fuzzy(Evidence evidence, AmbiguityReason reason) {
    return StateEvaluation(
      quadrant: Quadrant.fuzzy,
      investment: evidence.investment,
      depletion: evidence.depletion,
      confidence: evidence.confidence,
      evidence: evidence,
      ambiguityReason: reason,
    );
  }
}
