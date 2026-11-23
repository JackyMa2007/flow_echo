///心流回响 Beta-V0.1 全局常量与枚举定义
/// 和 api_contract.md 口径对齐
const double investmentHighThreshold = 0.55; //投入度高阈值，>0.55 判定高投入
const double depletionHighThreshold = 0.55; //消耗度高阈值，>0.55 判定高消耗
const double fuzzyLower = 0.45;             // 模糊区间下限
const double fuzzyUpper = 0.55;             // 模糊区间上限，0.45~0.55为边界模糊
const double idleHeartRateRise = 5.0;       // 空转条件：心率上升幅度阈值
const double idleInputThreshold = 0.25;     // 空转条件：输入活跃度阈值
const double idleSedentaryMinutes = 40.0;    // 空转条件：连续久坐至少40分钟
const int minimumFingerprintSamples = 20;    // 生成个人心流指纹最少样本数量
const int minimumFingerprintDays = 14;      // 生成个人心流指纹最少采集天数
const int defaultDailyInterruptBudget = 3;  // 每日恢复提醒上限次数
const Duration cloudPolishTimeout = Duration(seconds: 3); // 云端文案接口超时时间
const int sampleWindowSeconds = 30;          // 生理特征采样窗口：30秒一组
const int segmentMinutes = 20;               // 学习片段最小结算单元：20分钟

///场景标签枚举
enum SceneType { study, classSession, rest, entertainment }

extension SceneTypeX on SceneType {
  ///界面展示中文标签
  String get label {
    return switch (this) {
      SceneType.study => '自习',
      SceneType.classSession => '上课',
      SceneType.rest => '休息',
      SceneType.entertainment => '娱乐',
    };
  }

  ///是否参与心流指纹训练：自习，上课才参与
  bool get participatesInTraining {
    return this == SceneType.study || this == SceneType.classSession;
  }
}

///心流地图四象限+模糊
enum Quadrant { flow, challenge, idle, struggle, fuzzy }

extension QuadrantX on Quadrant {
  String get label {
    return switch (this) {
      Quadrant.flow => '顺流',
      Quadrant.challenge => '攻坚',
      Quadrant.idle => '空转',
      Quadrant.struggle => '苦撑',
      Quadrant.fuzzy => '模糊',
    };
  }
}

///判定结果为【模糊】时的原因
enum AmbiguityReason {
  insufficientData,
  featureConflict,
  nearBoundary,
  idleConditionsNotMet,
  missingBehaviorData,
}

extension AmbiguityReasonX on AmbiguityReason {
  String get label {
    return switch (this) {
      AmbiguityReason.insufficientData => '数据量不足，继续采集后才能判断',
      AmbiguityReason.featureConflict => '生理与输入特征冲突',
      AmbiguityReason.nearBoundary => '当前坐标处于象限边界',
      AmbiguityReason.idleConditionsNotMet => '未同时满足空转的三项证据',
      AmbiguityReason.missingBehaviorData => '行为数据缺失，暂时不判断象限',
    };
  }
}

///用户手动修正状态的原因
enum CorrectionReason { wrongState, wrongScene, inaccurateData }

///通知提醒等级 l0~l3
enum NotificationLevel { l0, l1, l2, l3 }

///认知负荷等级
enum CognitiveLoad { high, medium, low }

extension CognitiveLoadX on CognitiveLoad {
  String get label {
    return switch (this) {
      CognitiveLoad.high => '高认知负荷',
      CognitiveLoad.medium => '中认知负荷',
      CognitiveLoad.low => '低认知负荷',
    };
  }
}
