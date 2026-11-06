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
  _HomeData(this.open, this.streak, this.slots, this.dailyAvailable);
  final SavedGame? open;
  final Streak streak;
  /// Finished state of today's three daily puzzles, by slot.
  final List<bool> slots;
  int get todayDone => slots.where((d) => d).length;
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
    final slots = [for (var i = 0; i < 3; i++) status[i] == GamePhase.completed];
    if (!mounted) return;
    setState(() => _data = _HomeData(open, streak, slots, s.content.dailyFor(now) != null));
  }

  Future<void> _play(SavedGame saved) async {
    var current = saved;
    while (true) {
      if (!mounted) return;
      final exit = await Navigator.of(context).push<GameExit>(
        MaterialPageRoute(builder: (_) => GameScreen(saved: current)),
      );
      if (exit != GameExit.newGame || !mounted) break;
      // the one place for an interstitial: "Neues Sudoku" after a finished game (10.2)
      await ServicesScope.read(context).ads.onNewSudoku(current.game);
      if (!mounted) break;
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
                // header: one line, left-aligned like everything below
                Row(children: [
                  Expanded(
                    child: Text(s.appTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
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
                ]),
                const SizedBox(height: 20),
                if (data != null && data.dailyAvailable) ...[
                  _DailyCard(
                    streak: data.streak,
                    slots: data.slots,
                    onTap: _loading
                        ? null
                        : () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const DailyScreen()));
                            await _refresh();
                          },
                  ),
                  const SizedBox(height: 28),
                ],
                if (data?.open != null) ...[
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _play(data!.open!),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(s.continueGame(s.difficulty(data!.open!.game.difficulty))),
                  ),
                  const SizedBox(height: 28),
                ],
                Text(s.newGame, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(64, 52)),
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
  const _DailyCard({required this.streak, required this.slots, this.onTap});

  final Streak streak;
  final List<bool> slots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = context.s;
    final done = slots.where((d) => d).length;
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
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.dailyTitle, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
                Icon(Icons.chevron_right, size: 28, color: scheme.onSecondaryContainer),
              ]),
              const SizedBox(height: 10),
              // one calm line: today's three puzzles as circles, then the streak
              Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final d in slots)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(d ? Icons.check_circle : Icons.circle_outlined,
                            size: 26, color: d ? scheme.primary : scheme.onSecondaryContainer),
                      ),
                  ]),
                  Text(s.streakLine(streak.current), style: text.bodyLarge),
                ],
              ),
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
        // calm list: unselected levels are outlined, only the chosen one is filled
        color: selected ? scheme.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
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
