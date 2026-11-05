import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../data/game_repository.dart';
import '../../domain/daily/streak.dart';
import '../../domain/game/game.dart';
import '../../domain/sudoku/difficulty.dart';
import '../daily/daily_screen.dart';
import '../../l10n/strings.dart';
import '../game/game_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class _HomeData {
  _HomeData(this.open, this.streak, this.todayDone, this.dailyAvailable);
  final SavedGame? open;
  final Streak streak;
  final int todayDone;
  final bool dailyAvailable;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _level = Difficulty.easy;
  bool _loading = false;
  _HomeData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final last = await ServicesScope.read(context).games.setting('lastLevel');
      if (last != null && mounted) {
        setState(() => _level = Difficulty.values.asNameMap()[last] ?? Difficulty.easy);
      }
      await _refresh();
    });
  }

  Future<void> _refresh() async {
    final s = ServicesScope.read(context);
    final now = s.clock();
    final open = await s.games.openRegularGame();
    final streak = computeStreak(await s.games.completedDailyDays(), now);
    final status = await s.games.dailyStatus(dayKey(now));
    final done = status.values.where((p) => p == GamePhase.completed).length;
    if (!mounted) return;
    setState(() => _data = _HomeData(open, streak, done, s.content.dailyFor(now) != null));
  }

  Future<void> _play(SavedGame saved) async {
    var current = saved;
    while (true) {
      if (!mounted) return;
      final exit = await Navigator.of(context).push<GameExit>(
        MaterialPageRoute(builder: (_) => GameScreen(saved: current)),
      );
      if (exit != GameExit.newGame || !mounted) break;
      final next = await _newGame(current.game.difficulty);
      if (next == null) break;
      current = next;
    }
    await _refresh();
  }

  Future<SavedGame?> _newGame(Difficulty level) async {
    final s = ServicesScope.read(context);
    setState(() => _loading = true);
    try {
      final puzzle = await s.source(level, await s.games.recentFingerprints());
      return await s.games.startRegular(puzzle);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s.createFailed)));
      }
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    if (_loading) return; // no second game from a double tap
    if (_data?.open != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.s.discardTitle),
          content: Text(context.s.discardBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.s.discardConfirm)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await ServicesScope.read(context).games.setSetting('lastLevel', _level.name);
    final saved = await _newGame(_level);
    if (saved != null && mounted) await _play(saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    final data = _data;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: s.settings,
                    icon: const Icon(Icons.settings_outlined, size: 30),
                    onPressed: _loading
                        ? null
                        : () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
                            await _refresh();
                          },
                  ),
                ),
                Text(s.appTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(s.tagline, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 28),
                if (data != null && data.dailyAvailable) ...[
                  _DailyCard(
                    streak: data.streak,
                    done: data.todayDone,
                    onTap: _loading
                        ? null
                        : () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const DailyScreen()));
                            await _refresh();
                          },
                  ),
                  const SizedBox(height: 24),
                ],
                if (data?.open != null) ...[
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _play(data!.open!),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(s.continueGame(s.difficulty(data!.open!.game.difficulty))),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(s.newGame, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final d in Difficulty.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LevelTile(
                      label: s.difficulty(d),
                      selected: d == _level,
                      onTap: _loading ? null : () => setState(() => _level = d),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  style: data?.open != null
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          foregroundColor: theme.colorScheme.onSecondaryContainer)
                      : null,
                  onPressed: _loading ? null : _start,
                  child: _loading
                      ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3))
                      : Text(s.startGame),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StatsScreen())),
                  icon: const Icon(Icons.bar_chart),
                  label: Text(s.statistics, style: const TextStyle(fontSize: 18)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.streak, required this.done, this.onTap});

  final Streak streak;
  final int done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = context.s;
    return Semantics(
      button: true,
      label: s.dailyCardLabel(done, streak.current),
      excludeSemantics: true,
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(Icons.today, size: 36, color: scheme.onSecondaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.dailyTitle, style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(s.dailyToday(done), style: text.bodyLarge),
                  Text(s.streakLine(streak.current), style: text.bodyLarge),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 20))),
                if (selected) Icon(Icons.check_circle, color: scheme.primary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
