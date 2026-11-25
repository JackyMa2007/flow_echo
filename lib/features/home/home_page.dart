import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/home_live_controller.dart';
import '../../core/constants.dart';
import '../../providers/app_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(homeLiveControllerProvider).start());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(homeLiveControllerProvider);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state == null) {
          return _LoadingOrError(controller: controller);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('当前场景', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<SceneType>(
                showSelectedIcon: false,
                segments: SceneType.values
                    .map(
                      (scene) => ButtonSegment<SceneType>(
                        value: scene,
                        label: Text(scene.label),
                      ),
                    )
                    .toList(growable: false),
                selected: {state.session.scene},
                onSelectionChanged: controller.isSwitching
                    ? null
                    : (selection) {
                        unawaited(controller.switchScene(selection.first));
                      },
              ),
            ),
            const SizedBox(height: 20),
            _StateOverview(state: state),
            const SizedBox(height: 20),
            _Coordinates(state: state),
            const SizedBox(height: 20),
            _EvidenceSummary(state: state),
          ],
        );
      },
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.controller});

  final HomeLiveController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(controller.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => controller.start(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('正在准备模拟数据'),
        ],
      ),
    );
  }
}

class _StateOverview extends StatelessWidget {
  const _StateOverview({required this.state});

  final HomeLiveState state;

  @override
  Widget build(BuildContext context) {
    final evaluation = state.evaluation;
    final color = _quadrantColor(evaluation.quadrant);
    final reason = evaluation.ambiguityText;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  evaluation.quadrant.label,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '置信度 ${(evaluation.confidence * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reason ?? _quadrantDescription(evaluation.quadrant),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Coordinates extends StatelessWidget {
  const _Coordinates({required this.state});

  final HomeLiveState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('当前坐标', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _MetricBar(
          label: '投入度',
          value: state.evaluation.investment,
          color: const Color(0xFF2F6D5A),
        ),
        const SizedBox(height: 14),
        _MetricBar(
          label: '消耗度',
          value: state.evaluation.depletion,
          color: const Color(0xFFB05A36),
        ),
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${(value * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 8,
          color: color,
          backgroundColor: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _EvidenceSummary extends StatelessWidget {
  const _EvidenceSummary({required this.state});

  final HomeLiveState state;

  @override
  Widget build(BuildContext context) {
    final window = state.latestWindow;
    final evidence = state.evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('当前证据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _EvidenceChip(
              label: '心率',
              value: '${window.heartRate.round()} bpm',
            ),
            _EvidenceChip(label: 'HRV', value: '${window.hrv.round()} ms'),
            _EvidenceChip(
              label: '久坐',
              value: '${window.sedentaryMinutes.round()} 分钟',
            ),
            _EvidenceChip(
              label: '输入',
              value: '${(window.inputActivity * 100).round()}%',
            ),
            _EvidenceChip(label: '样本', value: '${evidence.sampleCount} 个窗口'),
          ],
        ),
      ],
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label $value'),
    );
  }
}

Color _quadrantColor(Quadrant quadrant) {
  return switch (quadrant) {
    Quadrant.flow => const Color(0xFF2F6D5A),
    Quadrant.challenge => const Color(0xFFA96B1F),
    Quadrant.idle => const Color(0xFF476B8F),
    Quadrant.struggle => const Color(0xFFA64545),
    Quadrant.fuzzy => const Color(0xFF6B6B6B),
  };
}

String _quadrantDescription(Quadrant quadrant) {
  return switch (quadrant) {
    Quadrant.flow => '持续输入且切换较少，当前更接近顺流状态。',
    Quadrant.challenge => '投入较高，但心率和久坐证据显示消耗也在上升。',
    Quadrant.idle => '心率高于个人基线、输入很低，并已久坐较长时间。',
    Quadrant.struggle => '投入较低而消耗较高，先恢复比继续加任务更合适。',
    Quadrant.fuzzy => '当前证据还不足以形成稳定判断。',
  };
}
