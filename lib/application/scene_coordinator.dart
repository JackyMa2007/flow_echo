import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../data/repositories/scene_session_repository.dart';
import '../domain/engine/state_evaluation.dart';
import '../domain/models/scene_session.dart';
import '../domain/models/state_snapshot.dart';

/// 管理当前场景和场景切换。
///
/// 页面不直接操作 scene_session 表，而是统一调用这个协调器。
class SceneCoordinator {
  SceneCoordinator(this._repository);

  final SceneSessionRepository _repository;
  final Uuid _uuid = const Uuid();

  SceneSession? _activeSession;
  StateEvaluation? _latestEvaluation;

  SceneSession? get activeSession => _activeSession;

  /// 从数据库恢复上次尚未结束的场景。
  Future<SceneSession?> restoreActiveSession() async {
    _activeSession = await _repository.findActiveSession();
    return _activeSession;
  }

  /// 第一次开始场景。
  Future<SceneSession> startScene(
    SceneType scene, {
    DateTime? startedAt,
  }) async {
    if (_activeSession != null) {
      throw StateError('已经有正在进行的场景，请使用 switchScene');
    }

    final now = startedAt ?? DateTime.now();
    final session = SceneSession(id: _uuid.v4(), scene: scene, startedAt: now);

    await _repository.insertSession(session);

    _activeSession = session;
    _latestEvaluation = null;
    return session;
  }

  /// 记录当前最新状态，切换场景时作为最后快照保存。
  void updateEvaluation(StateEvaluation evaluation) {
    _latestEvaluation = evaluation;
  }

  /// 切换场景：结束旧场景、保存最后快照、开始新场景。
  Future<SceneSession> switchScene(
    SceneType nextScene, {
    DateTime? switchedAt,
  }) async {
    final current = _activeSession;
    if (current == null) {
      return startScene(nextScene, startedAt: switchedAt);
    }

    if (current.scene == nextScene) {
      return current;
    }

    final now = switchedAt ?? DateTime.now();
    final nextSession = SceneSession(
      id: _uuid.v4(),
      scene: nextScene,
      startedAt: now,
    );
    final finalSnapshot = _buildFinalSnapshot(
      sceneSessionId: current.id,
      calculatedAt: now,
    );

    await _repository.switchScene(
      current: current,
      endedAt: now,
      next: nextSession,
      reason: SceneEndReason.sceneSwitch,
      finalSnapshot: finalSnapshot,
    );

    // 数据库事务成功后才更新内存状态。
    _activeSession = nextSession;
    _latestEvaluation = null;
    return nextSession;
  }

  /// 手动结束当前场景。
  Future<void> stopScene({DateTime? endedAt}) async {
    final current = _activeSession;
    if (current == null) {
      return;
    }

    final now = endedAt ?? DateTime.now();
    await _repository.completeSession(
      id: current.id,
      endedAt: now,
      reason: SceneEndReason.manualStop,
    );

    _activeSession = null;
    _latestEvaluation = null;
  }

  StateSnapshot? _buildFinalSnapshot({
    required String sceneSessionId,
    required DateTime calculatedAt,
  }) {
    final evaluation = _latestEvaluation;
    if (evaluation == null) {
      return null;
    }

    final reason = evaluation.ambiguityText;
    final displayText = reason == null
        ? evaluation.quadrant.label
        : '${evaluation.quadrant.label}：$reason';

    return StateSnapshot(
      id: _uuid.v4(),
      sceneSessionId: sceneSessionId,
      calculatedAt: calculatedAt,
      investment: evaluation.investment,
      depletion: evaluation.depletion,
      confidence: evaluation.confidence,
      quadrant: evaluation.quadrant,
      ambiguityReason: evaluation.ambiguityReason,
      evidence: evaluation.evidence.toJson(),
      templateText: displayText,
      displayText: displayText,
    );
  }
}
