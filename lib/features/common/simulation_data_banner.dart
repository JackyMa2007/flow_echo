import 'package:flutter/material.dart';

class SimulationDataBanner extends StatelessWidget {
  const SimulationDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFE7B3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Text(
        '演示模拟数据，仅用于产品功能验证',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF5C4300),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
