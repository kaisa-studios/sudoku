import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../domain/stats/statistics.dart';
import '../../domain/sudoku/difficulty.dart';
import '../../l10n/strings.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsReport? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final r = StatsReport(await ServicesScope.read(context).games.summaries());
      if (mounted) setState(() => _report = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final text = Theme.of(context).textTheme;
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.statistics)),
      body: SafeArea(
        child: r == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    if (r.overall.isEmpty && r.daily.isEmpty) ...[
                      Text(s.statsEmpty, style: text.titleMedium),
                      const SizedBox(height: 16),
                    ] else ...[
                      _Section(title: s.statsOverall, stats: r.overall),
                      for (final d in Difficulty.values)
                        if (!r.byLevel[d]!.isEmpty) _Section(title: s.difficulty(d), stats: r.byLevel[d]!),
                      if (!r.daily.isEmpty) _Section(title: s.dailyTitle, stats: r.daily),
                    ],
                    Text(s.statsExplanation, style: text.bodyMedium),
                  ]),
                ),
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.stats});

  final String title;
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final str = context.s;
    final s = stats;
    String time(num? ms) => ms == null ? '—' : formatDuration(ms.round());
    final rows = <(String, String)>[
      (str.statsStarted, '${s.started}'),
      (str.statsWon, '${s.won}'),
      (str.statsFailed, '${s.failed}'),
      (str.statsBestTime, time(s.bestMs)),
      (str.statsAverageTime, time(s.averageMs)),
      (str.statsAverageMistakes, s.averageMistakes == null ? '—' : str.decimal(s.averageMistakes!)),
      (str.statsSecondChance, '${s.secondChances}'),
      (str.statsFinishedAfterChance, '${s.finishedAfterSecondChance}'),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: text.titleLarge),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(label, style: text.bodyLarge)),
                const SizedBox(width: 12),
                Text(value, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    );
  }
}
