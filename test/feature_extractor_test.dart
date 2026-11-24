import 'package:flow_echo/core/constants.dart';
import 'package:flow_echo/domain/engine/feature_extractor.dart';
import 'package:flow_echo/domain/models/baseline_state.dart';
import 'package:flow_echo/domain/models/sensor_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = FeatureExtractor();
  final start = DateTime(2026, 11, 24, 9);
  final baseline = BaselineState.initial(start);

  List<SensorWindow> buildWindows({
    int count = 12,
    double heartRate = 78,
    double hrv = 54,
    double sedentaryMinutes = 25,
    double inputActivity = 0.70,
    int unlockCount = 1,
    int appSwitchCount = 1,
    SceneType scene = SceneType.study,
    int gapAt = -1,
  }) {
    return List.generate(count, (index) {
      final gap = gapAt >= 0 && index > gapAt
          ? const Duration(minutes: 10)
          : Duration.zero;
      return SensorWindow(
        id: 'window-$index',
        capturedAt: start.add(
          Duration(seconds: sampleWindowSeconds * index) + gap,
        ),
        scene: scene,
        heartRate: heartRate,
        hrv: hrv,
        sedentaryMinutes: sedentaryMinutes,
        unlockCount: unlockCount,
        inputActivity: inputActivity,
        appSwitchCount: appSwitchCount,
      );
    });
  }

  test('固定输入产生稳定的投入度、消耗度和置信度', () {
    final evidence = extractor.extract(
      windows: buildWindows(),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );

    expect(evidence.investment, inInclusiveRange(0, 1));
    expect(evidence.depletion, inInclusiveRange(0, 1));
    expect(evidence.confidence, inInclusiveRange(0, 1));
    expect(evidence.sampleCount, 12);
    expect(evidence.hasCompleteData, isTrue);
  });

  test('输入活跃度高且切换少时投入度更高', () {
    final highFocus = extractor.extract(
      windows: buildWindows(
        inputActivity: 0.85,
        appSwitchCount: 0,
        unlockCount: 0,
      ),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );
    final lowFocus = extractor.extract(
      windows: buildWindows(
        inputActivity: 0.10,
        appSwitchCount: 9,
        unlockCount: 10,
      ),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );

    expect(highFocus.investment, greaterThan(lowFocus.investment));
  });

  test('心率高、HRV低且久坐长时消耗度更高', () {
    final highLoad = extractor.extract(
      windows: buildWindows(heartRate: 95, hrv: 30, sedentaryMinutes: 65),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );
    final lowLoad = extractor.extract(
      windows: buildWindows(heartRate: 74, hrv: 55, sedentaryMinutes: 8),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );

    expect(highLoad.depletion, greaterThan(lowLoad.depletion));
  });

  test('样本不足时置信度降低并记录原因', () {
    final enough = extractor.extract(
      windows: buildWindows(),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );
    final insufficient = extractor.extract(
      windows: buildWindows(count: 3),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(seconds: 90)),
    );

    expect(insufficient.confidence, lessThan(enough.confidence));
    expect(insufficient.conflicts, contains('数据量不足'));
  });

  test('心率高、输入低、久坐超过40分钟时空转三条件成立', () {
    final evidence = extractor.extract(
      windows: buildWindows(
        heartRate: 82,
        sedentaryMinutes: 45,
        inputActivity: 0.10,
      ),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );

    expect(evidence.idleTripleSatisfied, isTrue);
  });

  test('空转三条件缺少任意一项时不成立', () {
    final evidence = extractor.extract(
      windows: buildWindows(
        heartRate: 76,
        sedentaryMinutes: 45,
        inputActivity: 0.10,
      ),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );

    expect(evidence.idleTripleSatisfied, isFalse);
  });

  test('采样断档时置信度下降并记录冲突', () {
    final continuous = extractor.extract(
      windows: buildWindows(),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 6)),
    );
    final gapped = extractor.extract(
      windows: buildWindows(gapAt: 5),
      baseline: baseline,
      scene: SceneType.study,
      now: start.add(const Duration(minutes: 16)),
    );

    expect(gapped.hasLargeGap, isTrue);
    expect(gapped.confidence, lessThan(continuous.confidence));
    expect(gapped.conflicts, contains('采样存在断档'));
  });
}
