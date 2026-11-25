import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';

/// 投入度-消耗度二维心流地图。
/// 横轴：投入度investment（0-1，越靠右投入度越高）
/// 纵轴：消耗度depletion（0-1，越靠上消耗越高）
/// 四个象限：苦撑、攻坚、空转、顺流；模糊带代表模型不确定区域
class FlowMap extends StatelessWidget {
  const FlowMap({
    super.key,
    required this.investment,
    required this.depletion,
    required this.confidence,
    required this.quadrant,
  });

  final double investment; // 投入度 0~1
  final double depletion; // 消耗度 0~1
  final double confidence; // 置信度：模型对当前判断有多大把握 0~1
  final Quadrant quadrant; // 当前判定属于哪个象限（顺流/攻坚/空转/苦撑/模糊）

  @override
  Widget build(BuildContext context) {
    // 防止外部传入超出0-1范围的脏数据，强制限制在合法区间
    final safeInvestment = investment.clamp(0.0, 1.0).toDouble();
    final safeDepletion = depletion.clamp(0.0, 1.0).toDouble();
    final safeConfidence = confidence.clamp(0.0, 1.0).toDouble();

    return Semantics(
      // 给读屏软件用的无障碍描述
      label:
          '心流地图，投入度${(safeInvestment * 100).round()}%，'
          '消耗度${(safeDepletion * 100).round()}%，'
          '当前状态${quadrant.label}',
      child: AspectRatio(
        aspectRatio: 1.05,
        child: CustomPaint(
          painter: FlowMapPainter(
            investment: safeInvestment,
            depletion: safeDepletion,
            confidence: safeConfidence,
            quadrant: quadrant,
          ),
          isComplex: true,
          willChange: true,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class FlowMapPainter extends CustomPainter {
  const FlowMapPainter({
    required this.investment,
    required this.depletion,
    required this.confidence,
    required this.quadrant,
  });

  final double investment;
  final double depletion;
  final double confidence;
  final Quadrant quadrant;

  /// 将 0~1 的心流坐标映射到画布区域，消耗度需要从下往上增长。
  @visibleForTesting
  static Offset mapPointToCanvas(
    double investment,
    double depletion,
    Rect chart,
  ) {
    return Offset(
      chart.left + investment.clamp(0.0, 1.0) * chart.width,
      chart.bottom - depletion.clamp(0.0, 1.0) * chart.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final chart = Rect.fromLTRB(
      math.max(42, size.width * 0.12),
      16,
      size.width - 16,
      size.height - 42,
    );

    if (chart.width <= 0 || chart.height <= 0) {
      return;
    }

    _drawBackground(canvas, chart); // 底色
    _drawQuadrants(canvas, chart); // 四个象限的浅色背景
    _drawFuzzyBands(canvas, chart); // 模糊条带：模型分不清的交界区域
    _drawGrid(canvas, chart); // 网格线 + 中心十字分割线
    _drawQuadrantLabels(canvas, chart); // 四个象限文字：苦撑、攻坚、空转、顺流
    _drawAxes(canvas, chart, size); // X轴Y轴名称：投入度、消耗度
    _drawCurrentPoint(canvas, chart); // 当前状态圆点（核心！用户实时位置）
  }

  //画布底色
  void _drawBackground(Canvas canvas, Rect chart) {
    canvas.drawRect(chart, Paint()..color = const Color(0xFFF2F4F1));
  }

  //绘制四个象限底色
  void _drawQuadrants(Canvas canvas, Rect chart) {
    final centerX = chart.center.dx;
    final centerY = chart.center.dy;
    //左上：苦撑|高消耗+低投入
    final struggleRect = Rect.fromLTRB(chart.left, chart.top, centerX, centerY);
    //右上：攻坚|高消耗+高投入
    final challengeRect = Rect.fromLTRB(
      centerX,
      chart.top,
      chart.right,
      centerY,
    );
    //左下：空转|低消耗+低投入
    final idleRect = Rect.fromLTRB(chart.left, centerY, centerX, chart.bottom);
    //右下：顺流|低消耗+高投入（理想心流状态)
    final flowRect = Rect.fromLTRB(centerX, centerY, chart.right, chart.bottom);

    canvas.drawRect(
      struggleRect,
      Paint()..color = const Color(0xFFA64545).withValues(alpha: 0.08),
    );
    canvas.drawRect(
      challengeRect,
      Paint()..color = const Color(0xFFA96B1F).withValues(alpha: 0.10),
    );
    canvas.drawRect(
      idleRect,
      Paint()..color = const Color(0xFF476B8F).withValues(alpha: 0.08),
    );
    canvas.drawRect(
      flowRect,
      Paint()..color = const Color(0xFF2F6D5A).withValues(alpha: 0.10),
    );

    //外边框
    canvas.drawRect(
      chart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF6F7971),
    );
  }

  // 模糊带：交界灰色条，落在里面代表模型判断不确定（对应fuzzy模糊状态）
  void _drawFuzzyBands(Canvas canvas, Rect chart) {
    final leftX = chart.left + fuzzyLower * chart.width;
    final rightX = chart.left + fuzzyUpper * chart.width;
    final topY = chart.bottom - fuzzyUpper * chart.height;
    final bottomY = chart.bottom - fuzzyLower * chart.height;

    final bandPaint = Paint()
      ..color = const Color(0xFF6B6B6B).withValues(alpha: 0.10);

    canvas.drawRect(
      Rect.fromLTRB(leftX, chart.top, rightX, chart.bottom),
      bandPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(chart.left, topY, chart.right, bottomY),
      bandPaint,
    );
  }

  //网格线：0.25 / 0.5 / 0.75刻度 + 中间十字分割线
  void _drawGrid(Canvas canvas, Rect chart) {
    final gridPaint = Paint()
      ..color = const Color(0xFF7A857D).withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (final value in const [0.25, 0.50, 0.75]) {
      final x = chart.left + value * chart.width;
      final y = chart.bottom - value * chart.height;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    //中心十字线（分割四个象限）
    final axisPaint = Paint()
      ..color = const Color(0xFF5F6A62).withValues(alpha: 0.35)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(chart.center.dx, chart.top),
      Offset(chart.center.dx, chart.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chart.left, chart.center.dy),
      Offset(chart.right, chart.center.dy),
      axisPaint,
    );
  }

  //四个象限文字标签
  void _drawQuadrantLabels(Canvas canvas, Rect chart) {
    _drawCenteredText(
      canvas,
      '苦撑',
      Offset(chart.left + chart.width * 0.25, chart.top + chart.height * 0.22),
      color: const Color(0xFFA64545),
    );
    _drawCenteredText(
      canvas,
      '攻坚',
      Offset(chart.left + chart.width * 0.75, chart.top + chart.height * 0.22),
      color: const Color(0xFFA96B1F),
    );
    _drawCenteredText(
      canvas,
      '空转',
      Offset(chart.left + chart.width * 0.25, chart.top + chart.height * 0.78),
      color: const Color(0xFF476B8F),
    );
    _drawCenteredText(
      canvas,
      '顺流',
      Offset(chart.left + chart.width * 0.75, chart.top + chart.height * 0.78),
      color: const Color(0xFF2F6D5A),
    );
  }

  // 坐标轴名称：底部「投入度」、左侧竖排「消耗度」
  void _drawAxes(Canvas canvas, Rect chart, Size size) {
    _drawCenteredText(
      canvas,
      '投入度',
      Offset(chart.center.dx, size.height - 14),
      color: const Color(0xFF465049),
      fontSize: 12,
    );

    canvas.save();
    canvas.translate(12, chart.center.dy);
    canvas.rotate(-math.pi / 2);
    _drawCenteredText(
      canvas,
      '消耗度',
      Offset.zero,
      color: const Color(0xFF465049),
      fontSize: 12,
    );
    canvas.restore();
  }

  // 绘制当前状态点：圆点大小跟着置信度变化，置信越高外圈越大
  void _drawCurrentPoint(Canvas canvas, Rect chart) {
    final point = FlowMapPainter.mapPointToCanvas(investment, depletion, chart);
    final color = _quadrantColor(quadrant);
    final outerRadius = 7 + confidence * 5;

    canvas.drawCircle(
      point,
      outerRadius,
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      point,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      point,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawCircle(point, 4, Paint()..color = color);
  }

  // 【坐标转换核心】把0~1的投入度、消耗度，转成画布上真实像素坐标
  // investment → x：往右变大
  // depletion → y：往上变大，所以用 chart.bottom 减去
  //通用工具：绘制居中文字
  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center, {
    Color color = const Color(0xFF445047),
    double fontSize = 13,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  //根据象限返回对应主题色
  Color _quadrantColor(Quadrant quadrant) {
    return switch (quadrant) {
      Quadrant.flow => const Color(0xFF2F6D5A), //顺流绿
      Quadrant.challenge => const Color(0xFFA96B1F), //攻坚橙
      Quadrant.idle => const Color(0xFF476B8F), //空转蓝
      Quadrant.struggle => const Color(0xFFA64545), //苦撑红
      Quadrant.fuzzy => const Color(0xFF6B6B6B), //模糊灰
    };
  }

  //判断要不要重绘：只要四个输入任意一个变了，就重新画图
  @override
  bool shouldRepaint(FlowMapPainter oldDelegate) {
    return investment != oldDelegate.investment ||
        depletion != oldDelegate.depletion ||
        confidence != oldDelegate.confidence ||
        quadrant != oldDelegate.quadrant;
  }
}
