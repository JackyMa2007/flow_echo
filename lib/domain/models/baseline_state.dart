import '../../core/constants.dart';
import '../../core/json_utils.dart';

///基线模型
///用于存放用户生理、行为基线参数，算法计算投入度/消耗度时以此为参照
class BaselineState {
  const BaselineState({
    required this.id,
    required this.kind,
    required this.effectiveAt,
    required this.heartRate,
    required this.heartRateStd,
    required this.hrv,
    required this.inputActivity,
    required this.unlockPer10Min,
    required this.investmentThreshold,
    required this.depletionThreshold,
    required this.source,
    this.expiresAt,
    this.isActive = true,
  });

  /// 构造初始默认基线（系统自带基线，用户还没有校准数据时使用）
  factory BaselineState.initial(DateTime now) {
    return BaselineState(
      id: 'baseline-default',
      kind: 'default',
      effectiveAt: now,
      heartRate: 72,
      heartRateStd: 8,
      hrv: 55,
      inputActivity: 0.55,
      unlockPer10Min: 2,
      investmentThreshold: investmentHighThreshold,
      depletionThreshold: depletionHighThreshold,
      source: 'system',
    );
  }

  /// 基线唯一标识
  final String id;

  /// 基线类型：default / calibrated（系统基线 / 用户校准基线）
  final String kind;

  /// 基线生效时间戳
  final DateTime effectiveAt;

  /// 基线过期时间，为空代表永久有效
  final DateTime? expiresAt;

  /// 基线平均心率
  final double heartRate;

  /// 心率标准差
  final double heartRateStd;

  /// 基线HRV
  final double hrv;

  /// 基线输入活跃度
  final double inputActivity;

  /// 基线每10分钟屏幕解锁次数
  final double unlockPer10Min;

  /// 投入度判定阈值
  final double investmentThreshold;

  /// 消耗度判定阈值
  final double depletionThreshold;

  /// 来源：system（系统）/ user（用户拖拽校准）
  final String source;

  /// 是否启用这条基线，同一时间只激活一条
  final bool isActive;

  /// 转为数据库存储map（toMap给sqflite入库）
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kind': kind,
      'effective_at': effectiveAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'baseline_json': encodeObjectMap(toJson()),
      'source': source,
      'is_active': isActive ? 1 : 0,
    };
  }

  /// 提取核心基线字段序列化为json，存入baseline_json文本字段
  Map<String, Object?> toJson() {
    return {
      'heartRate': heartRate,
      'heartRateStd': heartRateStd,
      'hrv': hrv,
      'inputActivity': inputActivity,
      'unlockPer10Min': unlockPer10Min,
      'investmentThreshold': investmentThreshold,
      'depletionThreshold': depletionThreshold,
    };
  }

  /// 从数据库读出的map还原BaselineState对象
  factory BaselineState.fromMap(Map<String, Object?> map) {
    final expiresAt = map['expires_at'] as int?;
    final json = decodeObjectMap(map['baseline_json']);
    return BaselineState(
      id: map['id']! as String,
      kind: map['kind']! as String,
      effectiveAt: DateTime.fromMillisecondsSinceEpoch(
        map['effective_at']! as int,
      ),
      expiresAt: expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAt),
      heartRate: (json['heartRate']! as num).toDouble(),
      heartRateStd: (json['heartRateStd']! as num).toDouble(),
      hrv: (json['hrv']! as num).toDouble(),
      inputActivity: (json['inputActivity']! as num).toDouble(),
      unlockPer10Min: (json['unlockPer10Min']! as num).toDouble(),
      investmentThreshold: (json['investmentThreshold']! as num).toDouble(),
      depletionThreshold: (json['depletionThreshold']! as num).toDouble(),
      source: map['source']! as String,
      isActive: (map['is_active']! as int) == 1,
    );
  }
}
