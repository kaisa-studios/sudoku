import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../domain/daily/streak.dart';
import '../../domain/game/game.dart';
import '../game/game_screen.dart';

const _months = [
  'Jänner', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Today's three daily puzzles and the streak (DECISIONS D7).
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  Map<int, GamePhase> _status = const {};
  Streak? _streak;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final s = ServicesScope.read(context);
    final now = s.clock();
    final status = await s.games.dailyStatus(dayKey(now));
    final streak = computeStreak(await s.games.completedDailyDays(), now);
    if (!mounted) return;
    setState(() {
      _status = status;
      _streak = streak;
    });
  }

  Future<void> _open(int slot) async {
    if (_busy) return;
    final s = ServicesScope.read(context);
    final now = s.clock();
    final puzzles = s.content.dailyFor(now);
    if (puzzles == null) return;
    setState(() => _busy = true);
    final key = dayKey(now);
    final saved = await s.games.dailyGame(key, slot) ?? await s.games.startDaily(puzzles[slot], key, slot);
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push<GameExit>(MaterialPageRoute(builder: (_) => GameScreen(saved: saved)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final now = s.clock();
    final puzzles = s.content.dailyFor(now);
    final text = Theme.of(context).textTheme;
    final streak = _streak;
    return Scaffold(
      appBar: AppBar(title: const Text('Tägliches Sudoku')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Text('${now.day}. ${_months[now.month - 1]} ${now.year}', style: text.headlineSmall),
              const SizedBox(height: 8),
              Text('Drei Rätsel pro Tag – für alle gleich.', style: text.bodyLarge),
              const SizedBox(height: 20),
              if (streak != null)
                Row(children: [
                  Expanded(child: _StatBox(label: 'Serie', value: _days(streak.current))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatBox(label: 'Beste Serie', value: _days(streak.best))),
                ]),
              const SizedBox(height: 24),
              if (puzzles == null)
                Text('Für heute sind keine Tagesrätsel verfügbar. Bitte aktualisiere die App.', style: text.bodyLarge)
              else
                for (var i = 0; i < puzzles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SlotTile(
                      title: difficultyLabel(puzzles[i].difficulty),
                      phase: _status[i],
                      onTap: _busy ? null : () => _open(i),
                    ),
                  ),
              const SizedBox(height: 8),
              Text('Ein Tag zählt für die Serie, sobald du mindestens ein Tagesrätsel gelöst hast.',
                  style: text.bodyMedium),
            ]),
          ),
        ),
      ),
    );
  }

  static String _days(int n) => n == 1 ? '1 Tag' : '$n Tage';
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.bodyLarge),
        Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.title, required this.phase, this.onTap});

  final String title;
  final GamePhase? phase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (status, icon) = switch (phase) {
      null => ('Starten', Icons.play_arrow),
      GamePhase.completed => ('Gelöst', Icons.check_circle),
      GamePhase.abandoned => ('Beendet', Icons.flag_outlined),
      _ => ('Weiterspielen', Icons.play_arrow),
    };
    final closed = phase == GamePhase.completed || phase == GamePhase.abandoned;
    return Semantics(
      button: !closed,
      label: '$title, $status',
      excludeSemantics: true,
      child: Material(
        color: phase == GamePhase.completed ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: closed ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500))),
                Text(status, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Icon(icon, color: scheme.primary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
