import 'dart:math';

import '../../core/constants.dart';
import '../models/baseline_state.dart';
import '../models/sensor_window.dart';
import 'evidence.dart';

/// 把一段时间的原始模拟数据整理成状态判定可以直接使用的证据。
///
/// 例如“心率82”本身没有意义，需要结合用户平时心率72才能判断是否偏高；
/// 所以这里会先做个人基线归一化，再计算投入、消耗和置信度。
class FeatureExtractor {
  const FeatureExtractor();

  /// 输入最近一段 SensorWindow、个人基线和当前场景，输出一份 Evidence。
  ///
  /// 这里不会判断顺流、攻坚、空转等最终标签，标签由 Day5 的 StateEngine 决定。
  Evidence extract({
    required List<SensorWindow> windows,
    required BaselineState baseline,
    required SceneType scene,
    required DateTime now,
  }) {
    if (windows.isEmpty) {
      throw ArgumentError.value(windows, 'windows', '不能对空窗口列表提取特征');
    }

    // 先按采集时间排序，避免调用方传入乱序数据导致“最新窗口”选错。
    final ordered = [...windows]
      ..sort((a, b) {
        return a.capturedAt.compareTo(b.capturedAt);
      });
    // 不完整窗口仍参与完整率计算，但不能伪装成可信的生理数据。
    final completeWindows = ordered
        .where((window) {
          return window.isComplete;
        })
        .toList(growable: false);
    final latest = completeWindows.isNotEmpty
        ? completeWindows.last
        : ordered.last;

    final sampleCount = completeWindows.length;
    final completeness = sampleCount / ordered.length;
    final hasLargeGap = _hasLargeGap(completeWindows);

    // 只根据窗口时间估算连续时长；最后一个30秒窗口也要算进去，所以加0.5分钟。
    final continuousMinutes = completeWindows.length < 2
        ? 0.0
        : completeWindows.last.capturedAt
                      .difference(completeWindows.first.capturedAt)
                      .inSeconds /
                  60 +
              sampleWindowSeconds / 120;

    // 心率Z表示“比个人平时高几个标准差”，不用所有人共用同一个固定阈值。
    final heartRateZ =
        (latest.heartRate - baseline.heartRate) /
        max(baseline.heartRateStd, minimumHeartRateStd);
    // HRV相对个人基线下降越多，通常说明身体或认知负荷越高。
    final hrvDrop = _clamp(
      1 - latest.hrv / max(baseline.hrv, minimumHrvForDivision),
      0,
      1,
    );

    // 以下分数都限制在0~1，方便后面按权重组合，不会因某项过大而淹没其他证据。
    final sedentaryScore = _clamp(
      (latest.sedentaryMinutes - sedentaryScoreStartMinutes) /
          sedentaryScoreSpanMinutes,
      0,
      1,
    );
    final inputScore = _clamp(
      latest.inputActivity / max(baseline.inputActivity, minimumInputBaseline),
      0,
      1,
    );
    final unlockScore = _clamp(
      (latest.unlockCount - baseline.unlockPer10Min) / unlockScoreSpan,
      0,
      1,
    );
    final switchPenalty = _clamp(
      latest.appSwitchCount / switchPenaltySpan,
      0,
      1,
    );
    final continuityScore = _clamp(
      continuousMinutes / continuityScoreMinutes,
      0,
      1,
    );
    final sceneRelevance = _sceneRelevance(scene);
    final heartRateLoad = _clamp(heartRateZ / heartRateLoadDivisor, 0, 1);
    final sustainedLoad = _clamp(
      continuousMinutes / sustainedLoadMinutes,
      0,
      1,
    );

    // 投入度高，代表用户正在持续输入、很少切屏和解锁，并且处于学习场景。
    final investment = _clamp(
      investmentInputWeight * inputScore +
          investmentSwitchWeight * (1 - switchPenalty) +
          investmentContinuityWeight * continuityScore +
          investmentUnlockWeight * (1 - unlockScore) +
          investmentSceneWeight * sceneRelevance,
      0,
      1,
    );
    // 消耗度高，代表HRV下降、心率偏高、久坐久或已经连续学了很长时间。
    final depletion = _clamp(
      depletionHrvWeight * hrvDrop +
          depletionHeartRateWeight * heartRateLoad +
          depletionSedentaryWeight * sedentaryScore +
          depletionSustainedWeight * sustainedLoad,
      0,
      1,
    );

    // 空转必须三条同时成立，缺任何一条都不能判为空转：
    // 心率高于个人基线 + 输入活跃度低 + 久坐超过40分钟。
    final idleTripleSatisfied =
        latest.heartRate > baseline.heartRate + idleHeartRateRise &&
        latest.inputActivity < idleInputThreshold &&
        latest.sedentaryMinutes >= idleSedentaryMinutes;

    // conflicts 不直接决定状态，而是告诉用户“为什么现在看不清”。
    final conflicts = <String>[];
    if (sampleCount < minimumFeatureSamples) {
      conflicts.add('数据量不足');
    }
    if (sampleCount == 0) {
      conflicts.add('没有完整数据');
    }
    if (hasLargeGap) {
      conflicts.add('采样存在断档');
    }
    if (latest.inputActivity < idleInputThreshold &&
        latest.heartRate <= baseline.heartRate + idleHeartRateRise) {
      conflicts.add('输入低但心率未升高');
    }
    if (latest.inputActivity > highInputConflictThreshold &&
        hrvDrop > hrvDropConflictThreshold) {
      conflicts.add('输入较高但HRV明显下降');
    }

    // 置信度由三部分组成：样本够不够、完整窗口比例、证据是否互相矛盾。
    final sampleConfidence = _clamp(sampleCount / confidenceSampleTarget, 0, 1);
    final consistencyConfidence = _clamp(
      1 - conflicts.length / maxConflictCountForConfidence,
      0,
      1,
    );
    var confidence =
        confidenceSampleWeight * sampleConfidence +
        confidenceCompletenessWeight * completeness +
        confidenceConsistencyWeight * consistencyConfidence;
    // 中间断了好几分钟时，即使窗口数量够，也不能表现得太自信。
    if (hasLargeGap) {
      confidence *= largeGapConfidenceMultiplier;
    }

    return Evidence(
      heartRate: latest.heartRate,
      baselineHeartRate: baseline.heartRate,
      heartRateZ: heartRateZ,
      hrv: latest.hrv,
      baselineHrv: baseline.hrv,
      hrvDrop: hrvDrop,
      sedentaryMinutes: latest.sedentaryMinutes,
      sedentaryScore: sedentaryScore,
      inputActivity: latest.inputActivity,
      inputScore: inputScore,
      unlockScore: unlockScore,
      switchPenalty: switchPenalty,
      continuityScore: continuityScore,
      continuousMinutes: continuousMinutes,
      sceneRelevance: sceneRelevance,
      investment: investment,
      depletion: depletion,
      confidence: _clamp(confidence, 0, 1),
      sampleCount: sampleCount,
      hasCompleteData: sampleCount > 0,
      hasLargeGap: hasLargeGap,
      idleTripleSatisfied: idleTripleSatisfied,
      conflicts: conflicts,
    );
  }

  /// 检查任意两个相邻窗口之间是否出现明显断档。
  static bool _hasLargeGap(List<SensorWindow> windows) {
    for (var index = 1; index < windows.length; index++) {
      final gap = windows[index].capturedAt.difference(
        windows[index - 1].capturedAt,
      );
      if (gap > const Duration(minutes: sensorGapMinutes)) {
        return true;
      }
    }
    return false;
  }

  /// 学习场景的投入权重最高，休息和娱乐不会轻易被算成学习投入。
  static double _sceneRelevance(SceneType scene) {
    return switch (scene) {
      SceneType.study => studySceneRelevance,
      SceneType.classSession => classSceneRelevance,
      SceneType.rest => restSceneRelevance,
      SceneType.entertainment => entertainmentSceneRelevance,
    };
  }

  /// 把所有计算值限制在指定范围内，避免公式异常时出现负数或超过100%。
  static double _clamp(num value, double lower, double upper) {
    return value.clamp(lower, upper).toDouble();
  }
}
