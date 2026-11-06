import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../domain/daily/streak.dart';
import '../../domain/game/game.dart';
import '../../l10n/strings.dart';
import '../game/game_screen.dart';

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
    final key = dayKey(now);
    int? next = slot;
    while (next != null && mounted) {
      final current = next;
      setState(() => _busy = true);
      final saved = await s.games.dailyGame(key, current) ?? await s.games.startDaily(puzzles[current], key, current);
      final status = await s.games.dailyStatus(key);
      bool open(int i) => i != current && status[i] != GamePhase.completed && status[i] != GamePhase.abandoned;
      final following = [for (var i = 0; i < puzzles.length; i++) if (open(i)) i];
      if (!mounted) return;
      setState(() => _busy = false);
      final exit = await Navigator.of(context).push<GameExit>(
        MaterialPageRoute(builder: (_) => GameScreen(saved: saved, hasNextDaily: following.isNotEmpty)),
      );
      next = null;
      if (exit == GameExit.nextDaily && following.isNotEmpty && mounted) {
        // between daily puzzles the same central rule applies as between games (D7, 10.2)
        await s.ads.onNewSudoku(saved.game);
        next = following.firstWhere((i) => i > current, orElse: () => following.first);
      }
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final now = s.clock();
    final puzzles = s.content.dailyFor(now);
    final text = Theme.of(context).textTheme;
    final str = context.s;
    final streak = _streak;
    return Scaffold(
      appBar: AppBar(title: Text(str.dailyTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Text(str.longDate(now), style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(str.dailyIntro, style: text.bodyLarge),
              const SizedBox(height: 20),
              if (streak != null)
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _StatBox(label: str.streak, value: str.days(streak.current)),
                  _StatBox(label: str.bestStreak, value: str.days(streak.best)),
                ]),
              const SizedBox(height: 24),
              if (puzzles == null)
                Text(str.dailyUnavailable, style: text.bodyLarge)
              else
                for (var i = 0; i < puzzles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SlotTile(
                      title: str.difficulty(puzzles[i].difficulty),
                      phase: _status[i],
                      onTap: _busy ? null : () => _open(i),
                    ),
                  ),
              const SizedBox(height: 8),
              Text(str.dailyStreakNote, style: text.bodyMedium),
            ]),
          ),
        ),
      ),
    );
  }
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
      constraints: const BoxConstraints(minWidth: 150),
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
    final s = context.s;
    final (status, icon) = switch (phase) {
      null => (s.slotStart, Icons.play_arrow),
      GamePhase.completed => (s.slotSolved, Icons.check_circle),
      GamePhase.abandoned => (s.slotEnded, Icons.flag_outlined),
      _ => (s.slotResume, Icons.play_arrow),
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
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(status, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Icon(icon, color: scheme.primary),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
