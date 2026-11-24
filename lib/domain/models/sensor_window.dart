import '../../core/constants.dart';

/// 传感器数据窗口模型
/// 30秒一帧的生理&行为快照窗口，Beta版为模拟数据，是投入度、消耗度算法的输入源
class SensorWindow {
  const SensorWindow({
    required this.id,
    required this.capturedAt,
    required this.scene,
    required this.heartRate,
    required this.hrv,
    required this.sedentaryMinutes,
    required this.unlockCount,
    required this.inputActivity,
    required this.appSwitchCount,
    this.dataSource = 'simulated',
    this.isComplete = true,
  });

  /// 窗口唯一ID
  final String id;

  /// 本窗口采集时间
  final DateTime capturedAt;

  /// 采集时所属场景标签
  final SceneType scene;

  /// 窗口平均心率
  final double heartRate;

  /// 窗口HRV
  final double hrv;

  /// 连续久坐时长（分钟）
  final double sedentaryMinutes;

  /// 窗口内屏幕解锁次数
  final int unlockCount;

  /// 输入活跃度
  final double inputActivity;

  /// 窗口内App切换次数
  final int appSwitchCount;

  /// 数据来源：simulated=模拟数据（Beta固定用这个）
  final String dataSource;

  /// 窗口数据是否完整，不完整的数据不参与状态计算
  final bool isComplete;

  /// 转为数据库存储Map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'captured_at': capturedAt.millisecondsSinceEpoch,
      'scene': scene.name,
      'heart_rate': heartRate,
      'hrv': hrv,
      'sedentary_minutes': sedentaryMinutes,
      'unlock_count': unlockCount,
      'input_activity': inputActivity,
      'app_switch_count': appSwitchCount,
      'data_source': dataSource,
      'is_complete': isComplete ? 1 : 0,
    };
  }

  /// 从数据库Map还原SensorWindow对象
  factory SensorWindow.fromMap(Map<String, Object?> map) {
    return SensorWindow(
      id: map['id']! as String,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        map['captured_at']! as int,
      ),
      scene: SceneType.values.byName(map['scene']! as String),
      heartRate: (map['heart_rate']! as num).toDouble(),
      hrv: (map['hrv']! as num).toDouble(),
      sedentaryMinutes: (map['sedentary_minutes']! as num).toDouble(),
      unlockCount: map['unlock_count']! as int,
      inputActivity: (map['input_activity']! as num).toDouble(),
      appSwitchCount: map['app_switch_count']! as int,
      dataSource: map['data_source']! as String,
      isComplete: (map['is_complete']! as int) == 1,
    );
  }
}

///就是你接口契约里算法函数的原始输入数据载体，Beta 里全部是 simulated 模拟数据流。
