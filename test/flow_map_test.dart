import 'dart:ui';

import 'package:flow_echo/features/home/widgets/flow_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const chart = Rect.fromLTRB(10, 20, 210, 220);

  test('心流地图四个角映射正确', () {
    expect(FlowMapPainter.mapPointToCanvas(0, 0, chart), const Offset(10, 220));
    expect(
      FlowMapPainter.mapPointToCanvas(1, 0, chart),
      const Offset(210, 220),
    );
    expect(FlowMapPainter.mapPointToCanvas(0, 1, chart), const Offset(10, 20));
    expect(FlowMapPainter.mapPointToCanvas(1, 1, chart), const Offset(210, 20));
  });

  test('坐标超出 0 到 1 时会被限制在地图内', () {
    expect(
      FlowMapPainter.mapPointToCanvas(-0.5, -1, chart),
      const Offset(10, 220),
    );
    expect(
      FlowMapPainter.mapPointToCanvas(1.5, 2, chart),
      const Offset(210, 20),
    );
  });
}
