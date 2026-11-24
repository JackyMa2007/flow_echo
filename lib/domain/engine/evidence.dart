/// 一次状态计算所使用的全部证据。
///
/// 原始数据经过 FeatureExtractor 后，会转成 0~1 的分值和可读的冲突原因。
/// Day5 的状态判定只读取 Evidence，不再重复做单位换算和归一化。
class Evidence {
  Evidence({
    required this.heartRate,
    required this.baselineHeartRate,
    required this.heartRateZ,
    required this.hrv,
    required this.baselineHrv,
    required this.hrvDrop,
    required this.sedentaryMinutes,
    required this.sedentaryScore,
    required this.inputActivity,
    required this.inputScore,
    required this.unlockScore,
    required this.switchPenalty,
    required this.continuityScore,
    required this.continuousMinutes,
    required this.sceneRelevance,
    required this.investment,
    required this.depletion,
    required this.confidence,
    required this.sampleCount,
    required this.hasCompleteData,
    required this.hasLargeGap,
    required this.idleTripleSatisfied,
    List<String> conflicts = const <String>[],
  }) : conflicts = List<String>.unmodifiable(conflicts);

  /// 当前心率，以及个人平时的心率基线。
  final double heartRate;
  final double baselineHeartRate;

  /// 心率相对个人基线高多少个“标准差”，比直接写固定心率更公平。
  final double heartRateZ;

  /// 当前 HRV、个人 HRV 基线，以及 HRV 相对下降了多大比例。
  final double hrv;
  final double baselineHrv;
  final double hrvDrop;

  /// 当前久坐时间和换算后的 0~1 久坐分数。
  final double sedentaryMinutes;
  final double sedentaryScore;

  /// 当前输入活跃度，以及相对个人基线换算后的 0~1 分数。
  final double inputActivity;
  final double inputScore;

  /// 解锁和切换越频繁，分数越高；它们会降低专注投入。
  final double unlockScore;
  final double switchPenalty;

  /// 连续学习时长，以及换算后的 0~1 连续性分数。
  final double continuousMinutes;
  final double continuityScore;

  /// 当前场景与“学习”的匹配程度，自习和上课最高。
  final double sceneRelevance;

  /// 三个最终结果：越投入越高、越消耗越高、越可信越高，范围都是 0~1。
  final double investment;
  final double depletion;
  final double confidence;

  /// 本次计算实际使用了多少个完整采样窗口。
  final int sampleCount;
  final bool hasCompleteData;
  final bool hasLargeGap;

  /// 空转三条件是否同时成立。Day5 再决定是否最终判为空转。
  final bool idleTripleSatisfied;

  /// 数据不足、断档或特征互相矛盾时，用通俗原因记录下来。
  final List<String> conflicts;

  int get conflictCount => conflicts.length;

  /// 转成快照的 evidence_json，方便以后追溯当时为什么得出这个结果。
  Map<String, Object?> toJson() {
    return {
      'heartRate': heartRate,
      'baselineHeartRate': baselineHeartRate,
      'heartRateZ': heartRateZ,
      'hrv': hrv,
      'baselineHrv': baselineHrv,
      'hrvDrop': hrvDrop,
      'sedentaryMinutes': sedentaryMinutes,
      'sedentaryScore': sedentaryScore,
      'inputActivity': inputActivity,
      'inputScore': inputScore,
      'unlockScore': unlockScore,
      'switchPenalty': switchPenalty,
      'continuityScore': continuityScore,
      'continuousMinutes': continuousMinutes,
      'sceneRelevance': sceneRelevance,
      'investment': investment,
      'depletion': depletion,
      'confidence': confidence,
      'sampleCount': sampleCount,
      'hasCompleteData': hasCompleteData,
      'hasLargeGap': hasLargeGap,
      'idleTripleSatisfied': idleTripleSatisfied,
      'conflicts': conflicts,
    };
  }
}
