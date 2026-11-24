import 'dart:convert';

import '../../core/constants.dart';

/// 推荐任务条目模型
/// 基于当前心流象限匹配适合的任务：根据认知负荷、适配象限做任务推荐
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.cognitiveLoad,
    required this.suitableQuadrants,
    required this.estimatedMinutes,
    this.enabled = true,
  });

  /// 任务唯一ID
  final String id;

  /// 任务名称
  final String title;

  /// 认知负荷等级
  final CognitiveLoad cognitiveLoad;

  /// 适合执行该任务的心流象限集合
  final Set<Quadrant> suitableQuadrants;

  /// 预估耗时（分钟）
  final int estimatedMinutes;

  /// 是否启用该任务，关闭后不再参与推荐
  final bool enabled;

  /// 转为数据库存储Map，Set集合json序列化存入
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'cognitive_load': cognitiveLoad.name,
      'suitable_quadrants': jsonEncode(
        suitableQuadrants.map((quadrant) => quadrant.name).toList(),
      ),
      'estimated_minutes': estimatedMinutes,
      'enabled': enabled ? 1 : 0,
    };
  }

  /// 从数据库Map还原TaskItem对象，json反序列化恢复Set
  factory TaskItem.fromMap(Map<String, Object?> map) {
    final quadrants = jsonDecode(map['suitable_quadrants']! as String) as List;
    return TaskItem(
      id: map['id']! as String,
      title: map['title']! as String,
      cognitiveLoad: CognitiveLoad.values.byName(
        map['cognitive_load']! as String,
      ),
      suitableQuadrants: quadrants
          .map((value) => Quadrant.values.byName(value as String))
          .toSet(),
      estimatedMinutes: map['estimated_minutes']! as int,
      enabled: (map['enabled']! as int) == 1,
    );
  }
}

///任务库，算法根据当前象限，挑选匹配的任务给用户推荐
