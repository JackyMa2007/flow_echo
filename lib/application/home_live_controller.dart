import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../data/repositories/baseline_repository.dart';
import '../domain/engine/evidence.dart';
import '../domain/engine/feature_extractor.dart';
import '../domain/engine/state_engine.dart';
import '../domain/engine/state_evaluation.dart';
import '../domain/models/baseline_state.dart';
import '../domain/models/scene_session.dart';
import '../domain/models/sensor_window.dart';
import '../simulation/sensor_simulator.dart';
import 'scene_coordinator.dart';

/// 首页当前展示所需的完整数据。
class HomeLiveState {
  const HomeLiveState({
    required this.baseline,
    required this.session,
    required this.latestWindow,
    required this.evidence,
    required this.evaluation,
  });

  final BaselineState baseline;
  final SceneSession session;
  final SensorWindow latestWindow;
  final Evidence evidence;
  final StateEvaluation evaluation;
}

/// 把模拟器、特征提取、状态引擎和场景切换串成首页实时数据流。
class HomeLiveController extends ChangeNotifier {
  HomeLiveController(
    this._simulator,
    this._baselineRepository,
    this._featureExtractor,
    this._stateEngine,
    this._sceneCoordinator, {
    this.tickInterval = SensorSimulator.sampleInterval,
    this.initialSampleCount = minimumFeatureSamples,
  });

  final SensorSimulator _simulator;
  final BaselineRepository _baselineRepository;
  final FeatureExtractor _featureExtractor;
  final StateEngine _stateEngine;
  final SceneCoordinator _sceneCoordinator;
  final Duration tickInterval;
  final int initialSampleCount;

  final List<SensorWindow> _windows = [];
  HomeLiveState? _state;
  Timer? _timer;
  bool _initializing = false;
  bool _switching = false;
  String? _error;

  HomeLiveState? get state => _state;
  bool get isLoading => _initializing && _state == null;
  bool get isSwitching => _switching;
  String? get error => _error;
  SceneType? get activeScene => _state?.session.scene;

  Future<void> start() async {
    if (_state != null || _initializing) {
      return;
    }

    _initializing = true;
    _error = null;
    notifyListeners();

    try {
      final baseline = await _baselineRepository.getActive();
      var session = await _sceneCoordinator.restoreActiveSession();
      session ??= await _sceneCoordinator.startScene(SceneType.study);

      _simulator.setScene(session.scene);
      _seedWindows(session.startedAt);
      _emitState(baseline, session);
      _timer ??= Timer.periodic(tickInterval, (_) => _tick());
    } catch (error) {
      _error = '模拟数据初始化失败：$error';
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> switchScene(SceneType scene) async {
    final current = _state;
    if (current == null || _switching || current.session.scene == scene) {
      return;
    }

    _switching = true;
    notifyListeners();

    try {
      final nextSession = await _sceneCoordinator.switchScene(scene);
      _simulator.setScene(scene);
      _windows.clear();
      _seedWindows(nextSession.startedAt);
      _emitState(current.baseline, nextSession);
      _error = null;
    } catch (error) {
      _error = '场景切换失败：$error';
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  void _seedWindows(DateTime startedAt) {
    for (var index = 0; index < initialSampleCount; index++) {
      _windows.add(
        _simulator.next(
          now: startedAt.add(Duration(seconds: sampleWindowSeconds * index)),
        ),
      );
    }
  }

  void _tick() {
    final current = _state;
    if (current == null || _switching) {
      return;
    }

    _windows.add(_simulator.next());
    if (_windows.length > confidenceSampleTarget) {
      _windows.removeAt(0);
    }

    final evidence = _featureExtractor.extract(
      windows: _windows,
      baseline: current.baseline,
      scene: current.session.scene,
      now: DateTime.now(),
    );
    final evaluation = _stateEngine.evaluate(
      evidence: evidence,
      baseline: current.baseline,
    );

    _sceneCoordinator.updateEvaluation(evaluation);
    _state = HomeLiveState(
      baseline: current.baseline,
      session: current.session,
      latestWindow: _windows.last,
      evidence: evidence,
      evaluation: evaluation,
    );
    notifyListeners();
  }

  void _emitState(BaselineState baseline, SceneSession session) {
    final evidence = _featureExtractor.extract(
      windows: _windows,
      baseline: baseline,
      scene: session.scene,
      now: DateTime.now(),
    );
    final evaluation = _stateEngine.evaluate(
      evidence: evidence,
      baseline: baseline,
    );

    _sceneCoordinator.updateEvaluation(evaluation);
    _state = HomeLiveState(
      baseline: baseline,
      session: session,
      latestWindow: _windows.last,
      evidence: evidence,
      evaluation: evaluation,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
