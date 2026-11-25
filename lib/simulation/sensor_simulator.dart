import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../domain/models/baseline_state.dart';
import '../domain/models/sensor_window.dart';
import 'simulation_profiles.dart';
import 'simulation_scenario.dart';

class SensorSimulator {
  SensorSimulator({
    int seed = 20261124,
    SimulationScenario scenario = SimulationScenario.flow,
    SceneType scene = SceneType.study,
    BaselineState? baseline,
    DateTime Function()? clock,
  }) : _random = Random(seed),
       _uuid = const Uuid(),
       _clock = clock ?? DateTime.now,
       // ignore: prefer_initializing_formals
       _scenario = scenario,
       // ignore: prefer_initializing_formals
       _scene = scene {
    _baseline = baseline ?? BaselineState.initial(_clock());
    _heartRate = _baseline.heartRate;
    _hrv = _baseline.hrv;
    _inputActivity = _baseline.inputActivity;
    // 空转演示需要从“已经久坐”的状态开始，否则短时间内无法满足三条件。
    _sedentaryMinutes = scenario == SimulationScenario.idle
        ? idleSedentaryMinutes
        : 5;
    _unlockCount = _baseline.unlockPer10Min.round().toDouble();
    _appSwitchCount = 2;
  }

  static const Duration sampleInterval = Duration(seconds: sampleWindowSeconds);

  final Random _random;
  final Uuid _uuid;
  final DateTime Function() _clock;

  late final BaselineState _baseline;
  late double _heartRate;
  late double _hrv;
  late double _inputActivity;
  late double _sedentaryMinutes;
  late double _unlockCount;
  late double _appSwitchCount;

  SimulationScenario _scenario;
  SceneType _scene;
  DateTime? _lastCapturedAt;

  SimulationScenario get scenario => _scenario;
  SceneType get scene => _scene;
  BaselineState get baseline => _baseline;

  void setScenario(SimulationScenario scenario) {
    _scenario = scenario;
    if (scenario == SimulationScenario.idle) {
      _sedentaryMinutes = max(_sedentaryMinutes, idleSedentaryMinutes);
    }
  }

  void setScene(SceneType scene) {
    _scene = scene;
    if (!scene.participatesInTraining) {
      _sedentaryMinutes = 0;
    }
  }

  SensorWindow next({DateTime? now, String dataSource = 'simulated'}) {
    final profile = simulationProfiles[_scenario]!;
    final capturedAt = now ?? _lastCapturedAt?.add(sampleInterval) ?? _clock();

    final targetHeartRate =
        _baseline.heartRate + profile.heartRateOffset.sample(_random);
    final targetHrv = _baseline.hrv * profile.hrvMultiplier.sample(_random);
    final targetInput = profile.inputActivity.sample(_random);
    final targetSedentary = profile.sedentaryMinutes.sample(_random);
    final targetUnlock = profile.unlockCount.sample(_random).toDouble();
    final targetSwitch = profile.appSwitchCount.sample(_random).toDouble();

    _heartRate = _drift(_heartRate, targetHeartRate, 1.2);
    _hrv = _drift(_hrv, targetHrv, 1.5);
    _inputActivity = _drift(_inputActivity, targetInput, 0.05);
    _sedentaryMinutes = _drift(_sedentaryMinutes, targetSedentary, 2.0);
    _unlockCount = _drift(_unlockCount, targetUnlock, 0.8);
    _appSwitchCount = _drift(_appSwitchCount, targetSwitch, 0.7);
    _lastCapturedAt = capturedAt;

    return SensorWindow(
      id: _uuid.v4(),
      capturedAt: capturedAt,
      scene: _scene,
      heartRate: _heartRate,
      hrv: _hrv,
      sedentaryMinutes: _sedentaryMinutes,
      unlockCount: _unlockCount.round(),
      inputActivity: _inputActivity,
      appSwitchCount: _appSwitchCount.round(),
      dataSource: dataSource,
    );
  }

  Stream<SensorWindow> windows({
    required SceneType scene,
    Duration interval = sampleInterval,
  }) async* {
    setScene(scene);

    while (true) {
      yield next(now: _clock());
      await Future<void>.delayed(interval);
    }
  }

  static double _drift(double current, double target, double step) {
    if ((target - current).abs() <= step) {
      return target;
    }
    return current + (target > current ? step : -step);
  }
}
