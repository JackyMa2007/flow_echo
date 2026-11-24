import 'dart:math';

import 'simulation_scenario.dart';

class DoubleRange {
  const DoubleRange(this.min, this.max) : assert(min <= max);

  final double min;
  final double max;

  double sample(Random random) {
    return min + random.nextDouble() * (max - min);
  }
}

class IntRange {
  const IntRange(this.min, this.max) : assert(min <= max);

  final int min;
  final int max;

  int sample(Random random) {
    return min + random.nextInt(max - min + 1);
  }
}

class SimulationProfile {
  const SimulationProfile({
    required this.heartRateOffset,
    required this.hrvMultiplier,
    required this.inputActivity,
    required this.unlockCount,
    required this.appSwitchCount,
    required this.sedentaryMinutes,
  });

  final DoubleRange heartRateOffset;
  final DoubleRange hrvMultiplier;
  final DoubleRange inputActivity;
  final IntRange unlockCount;
  final IntRange appSwitchCount;
  final DoubleRange sedentaryMinutes;
}

const Map<SimulationScenario, SimulationProfile> simulationProfiles = {
  SimulationScenario.flow: SimulationProfile(
    heartRateOffset: DoubleRange(3, 8),
    hrvMultiplier: DoubleRange(0.95, 1.05),
    inputActivity: DoubleRange(0.55, 0.85),
    unlockCount: IntRange(0, 2),
    appSwitchCount: IntRange(0, 2),
    sedentaryMinutes: DoubleRange(10, 25),
  ),
  SimulationScenario.challenge: SimulationProfile(
    heartRateOffset: DoubleRange(10, 18),
    hrvMultiplier: DoubleRange(0.75, 0.90),
    inputActivity: DoubleRange(0.55, 0.90),
    unlockCount: IntRange(1, 4),
    appSwitchCount: IntRange(1, 4),
    sedentaryMinutes: DoubleRange(45, 70),
  ),
  SimulationScenario.idle: SimulationProfile(
    heartRateOffset: DoubleRange(5, 12),
    hrvMultiplier: DoubleRange(0.95, 1.05),
    inputActivity: DoubleRange(0.00, 0.20),
    unlockCount: IntRange(6, 12),
    appSwitchCount: IntRange(5, 10),
    sedentaryMinutes: DoubleRange(45, 60),
  ),
  SimulationScenario.struggle: SimulationProfile(
    heartRateOffset: DoubleRange(12, 22),
    hrvMultiplier: DoubleRange(0.65, 0.80),
    inputActivity: DoubleRange(0.05, 0.35),
    unlockCount: IntRange(3, 9),
    appSwitchCount: IntRange(3, 7),
    sedentaryMinutes: DoubleRange(30, 50),
  ),
  SimulationScenario.fuzzy: SimulationProfile(
    heartRateOffset: DoubleRange(4, 12),
    hrvMultiplier: DoubleRange(0.95, 1.05),
    inputActivity: DoubleRange(0.40, 0.80),
    unlockCount: IntRange(5, 10),
    appSwitchCount: IntRange(5, 11),
    sedentaryMinutes: DoubleRange(20, 45),
  ),
};
