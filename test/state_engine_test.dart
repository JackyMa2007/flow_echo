import 'package:flow_echo/core/constants.dart';
import 'package:flow_echo/domain/engine/evidence.dart';
import 'package:flow_echo/domain/engine/state_engine.dart';
import 'package:flow_echo/domain/models/baseline_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = StateEngine();
  final baseline = BaselineState.initial(DateTime(2026, 11, 24, 9));

  Evidence evidence({
    double investment = 0.70,
    double depletion = 0.30,
    double confidence = 0.80,
    int sampleCount = 12,
    bool hasCompleteData = true,
    bool hasLargeGap = false,
    bool idleTripleSatisfied = false,
    double heartRate = 78,
    double inputActivity = 0.70,
    double sedentaryMinutes = 20,
  }) {
    return Evidence(
      heartRate: heartRate,
      baselineHeartRate: baseline.heartRate,
      heartRateZ: 0.75,
      hrv: 55,
      baselineHrv: baseline.hrv,
      hrvDrop: 0,
      sedentaryMinutes: sedentaryMinutes,
      sedentaryScore: 0.2,
      inputActivity: inputActivity,
      inputScore: 0.8,
      unlockScore: 0,
      switchPenalty: 0,
      continuityScore: 0.7,
      continuousMinutes: 28,
      sceneRelevance: 1,
      investment: investment,
      depletion: depletion,
      confidence: confidence,
      sampleCount: sampleCount,
      hasCompleteData: hasCompleteData,
      hasLargeGap: hasLargeGap,
      idleTripleSatisfied: idleTripleSatisfied,
    );
  }

  test('样本不足返回模糊并说明数据量不足', () {
    final result = engine.evaluate(
      evidence: evidence(sampleCount: 5),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.insufficientData);
  });

  test('没有完整数据返回模糊', () {
    final result = engine.evaluate(
      evidence: evidence(hasCompleteData: false),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.insufficientData);
  });

  test('采样断档返回模糊', () {
    final result = engine.evaluate(
      evidence: evidence(hasLargeGap: true),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.insufficientData);
  });

  test('置信度不足时不强行判断象限', () {
    final result = engine.evaluate(
      evidence: evidence(confidence: 0.59),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.featureConflict);
  });

  test('空转三条件成立时返回空转', () {
    final result = engine.evaluate(
      evidence: evidence(
        investment: 0.50,
        depletion: 0.50,
        idleTripleSatisfied: true,
        heartRate: 82,
        inputActivity: 0.10,
        sedentaryMinutes: 45,
      ),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.idle);
  });

  test('坐标靠近边界时返回边界模糊', () {
    final result = engine.evaluate(
      evidence: evidence(investment: 0.50, depletion: 0.30),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.nearBoundary);
  });

  test('高投入低消耗返回顺流', () {
    final result = engine.evaluate(
      evidence: evidence(investment: 0.72, depletion: 0.30),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.flow);
  });

  test('高投入高消耗返回攻坚', () {
    final result = engine.evaluate(
      evidence: evidence(investment: 0.72, depletion: 0.72),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.challenge);
  });

  test('低投入高消耗返回苦撑', () {
    final result = engine.evaluate(
      evidence: evidence(investment: 0.30, depletion: 0.72),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.struggle);
  });

  test('低投入低消耗但空转条件不成立时返回模糊', () {
    final result = engine.evaluate(
      evidence: evidence(investment: 0.30, depletion: 0.30),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.idleConditionsNotMet);
  });

  test('久坐和低输入存在但心率未升高时返回特征冲突', () {
    final result = engine.evaluate(
      evidence: evidence(
        investment: 0.30,
        depletion: 0.30,
        heartRate: 76,
        inputActivity: 0.10,
        sedentaryMinutes: 45,
      ),
      baseline: baseline,
    );

    expect(result.quadrant, Quadrant.fuzzy);
    expect(result.ambiguityReason, AmbiguityReason.featureConflict);
  });
}
