import 'package:flow_echo/core/constants.dart';
import 'package:flow_echo/domain/models/baseline_state.dart';
import 'package:flow_echo/domain/models/sensor_window.dart';
import 'package:flow_echo/simulation/sensor_simulator.dart';
import 'package:flow_echo/simulation/simulation_scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseline = BaselineState.initial(DateTime(2026, 11, 24, 9));

  SensorSimulator createSimulator({
    SimulationScenario scenario = SimulationScenario.flow,
    int seed = 20261124,
  }) {
    return SensorSimulator(baseline: baseline, scenario: scenario, seed: seed);
  }

  test('提供五种演示剧本', () {
    expect(
      SimulationScenario.values.map((scenario) => scenario.label),
      containsAll(['顺流', '攻坚', '空转', '苦撑', '模糊']),
    );
  });

  test('同一随机种子生成相同数据', () {
    final first = createSimulator(scenario: SimulationScenario.challenge);
    final second = createSimulator(scenario: SimulationScenario.challenge);
    final now = DateTime(2026, 11, 24, 9, 30);

    final firstWindow = first.next(now: now);
    final secondWindow = second.next(now: now);

    expect(firstWindow.heartRate, secondWindow.heartRate);
    expect(firstWindow.hrv, secondWindow.hrv);
    expect(firstWindow.inputActivity, secondWindow.inputActivity);
    expect(firstWindow.unlockCount, secondWindow.unlockCount);
  });

  test('默认采样间隔是 30 秒', () {
    expect(SensorSimulator.sampleInterval, const Duration(seconds: 30));
  });

  test('空转剧本最终满足心率高、输入低和久坐条件', () {
    final simulator = createSimulator(scenario: SimulationScenario.idle);
    SensorWindow? window;

    for (var index = 0; index < 30; index++) {
      window = simulator.next(
        now: DateTime(
          2026,
          11,
          24,
          9,
        ).add(SensorSimulator.sampleInterval * index),
      );
    }

    expect(window, isNotNull);
    expect(window!.heartRate, greaterThan(baseline.heartRate + 5));
    expect(window.inputActivity, lessThan(idleInputThreshold));
    expect(window.sedentaryMinutes, greaterThanOrEqualTo(40));
  });

  test('攻坚比顺流产生更高的消耗信号', () {
    final flow = createSimulator(scenario: SimulationScenario.flow);
    final challenge = createSimulator(scenario: SimulationScenario.challenge);
    final now = DateTime(2026, 11, 24, 10);

    SensorWindow? flowWindow;
    SensorWindow? challengeWindow;
    for (var index = 0; index < 20; index++) {
      flowWindow = flow.next(now: now.add(Duration(minutes: index)));
      challengeWindow = challenge.next(now: now.add(Duration(minutes: index)));
    }

    expect(flowWindow, isNotNull);
    expect(challengeWindow, isNotNull);
    expect(challengeWindow!.heartRate, greaterThan(flowWindow!.heartRate));
    expect(challengeWindow.hrv, lessThan(flowWindow.hrv));
  });

  test('模拟窗口携带场景和模拟数据来源', () {
    final simulator = createSimulator();
    simulator.setScene(SceneType.classSession);
    final window = simulator.next(now: DateTime(2026, 11, 24, 11));

    expect(window.scene, SceneType.classSession);
    expect(window.dataSource, 'simulated');
    expect(window.isComplete, isTrue);
  });
}
