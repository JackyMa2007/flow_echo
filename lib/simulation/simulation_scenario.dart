enum SimulationScenario { flow, challenge, idle, struggle, fuzzy }

extension SimulationScenarioX on SimulationScenario {
  String get label {
    return switch (this) {
      SimulationScenario.flow => '顺流',
      SimulationScenario.challenge => '攻坚',
      SimulationScenario.idle => '空转',
      SimulationScenario.struggle => '苦撑',
      SimulationScenario.fuzzy => '模糊',
    };
  }
}
