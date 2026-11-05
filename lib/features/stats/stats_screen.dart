import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../domain/stats/statistics.dart';
import '../../domain/sudoku/difficulty.dart';
import '../game/game_screen.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: SafeArea(
        child: r == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    if (r.overall.isEmpty && r.daily.isEmpty) ...[
                      Text('Noch keine Spiele – starte dein erstes Sudoku.', style: text.titleMedium),
                      const SizedBox(height: 16),
                    ] else ...[
                      _Section(title: 'Gesamt', stats: r.overall),
                      for (final d in Difficulty.values)
                        if (!r.byLevel[d]!.isEmpty) _Section(title: difficultyLabel(d), stats: r.byLevel[d]!),
                      if (!r.daily.isEmpty) _Section(title: 'Tägliches Sudoku', stats: r.daily),
                    ],
                    Text(
                      'Ab drei Fehlern zählt ein Sudoku als nicht geschafft – auch wenn du es mit der zweiten '
                      'Chance zu Ende spielst. Freiwillig verworfene Spiele sind keine Niederlagen. Bestzeit und '
                      'Durchschnittszeit zählen nur geschaffte Spiele ohne Hinweise. Durchschnittliche Fehler: '
                      'über alle beendeten Spiele.',
                      style: text.bodyMedium,
                    ),
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
    final s = stats;
    String time(num? ms) => ms == null ? '—' : formatDuration(ms.round());
    final rows = <(String, String)>[
      ('Gestartet', '${s.started}'),
      ('Geschafft', '${s.won}'),
      ('Nicht geschafft', '${s.failed}'),
      ('Beste Zeit', time(s.bestMs)),
      ('Durchschnittszeit', time(s.averageMs)),
      ('Durchschnittliche Fehler',
          s.averageMistakes == null ? '—' : s.averageMistakes!.toStringAsFixed(1).replaceAll('.', ',')),
      ('Mit zweiter Chance', '${s.secondChances}'),
      ('Nach zweiter Chance fertig', '${s.finishedAfterSecondChance}'),
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
                Text(value, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    );
  }
}
