/// Deterministic, human-style solver used to rate difficulty.
///
/// It never guesses. At every step it applies the cheapest allowed strategy
/// that makes progress (placement or elimination) and records which
/// strategies were needed. If a solution is passed as oracle, every
/// placement and elimination is checked against it; tests use this to prove
/// that no strategy ever removes the true digit.
library;

import 'difficulty.dart';
import 'grid.dart';

class LogicResult {
  LogicResult({
    required this.solved,
    required this.grid,
    required this.counts,
    required this.steps,
    required this.oracleViolations,
    required this.contradiction,
  });

  final bool solved;
  final List<int> grid;
  final Map<Strategy, int> counts;
  final int steps;
  final int oracleViolations;
  final bool contradiction;

  /// Hardest strategy that was needed, or null if none (already solved).
  Strategy? get hardest {
    Strategy? h;
    for (final s in counts.keys) {
      if (counts[s]! > 0 && (h == null || s.index > h.index)) h = s;
    }
    return h;
  }

  int get score =>
      counts.entries.fold(0, (sum, e) => sum + e.key.weight * e.value);
}

class LogicSolver {
  LogicSolver(List<int> puzzle, {this.oracle})
      : values = List.of(puzzle),
        cand = List.filled(cellCount, 0) {
    for (var c = 0; c < cellCount; c++) {
      if (values[c] != 0) continue;
      var used = 0;
      for (final p in peers[c]) {
        if (values[p] != 0) used |= 1 << values[p];
      }
      cand[c] = allDigits & ~used;
    }
  }

  final List<int> values;
  final List<int> cand;
  /// Known solution; when set, every step is checked against it (tests).
  final List<int>? oracle;
  int violations = 0;

  bool get solved => !values.contains(0);

  bool get contradiction {
    for (var c = 0; c < cellCount; c++) {
      if (values[c] == 0 && cand[c] == 0) return true;
    }
    return false;
  }

  LogicResult run(List<Strategy> allowed, {int maxSteps = 2000}) {
    final counts = <Strategy, int>{for (final s in allowed) s: 0};
    var steps = 0;
    while (!solved && steps < maxSteps) {
      if (contradiction) break;
      var progress = false;
      for (final s in allowed) {
        if (_apply(s)) {
          counts[s] = counts[s]! + 1;
          progress = true;
          break;
        }
      }
      if (!progress) break;
      steps++;
    }
    return LogicResult(
      solved: solved,
      grid: List.of(values),
      counts: counts,
      steps: steps,
      oracleViolations: violations,
      contradiction: contradiction,
    );
  }

  // ------------------------------------------------------------ primitives --

  void _place(int c, int d) {
    final o = oracle;
    if (o != null && o[c] != d) violations++;
    values[c] = d;
    cand[c] = 0;
    final b = ~(1 << d);
    for (final p in peers[c]) {
      cand[p] &= b;
    }
  }

  /// Removes [mask] from cell [c]; returns true if something changed.
  bool _elim(int c, int mask) {
    if (values[c] != 0 || cand[c] & mask == 0) return false;
    final o = oracle;
    if (o != null && cand[c] & mask & (1 << o[c]) != 0) violations++;
    cand[c] &= ~mask;
    return true;
  }

  bool _apply(Strategy s) {
    switch (s) {
      case Strategy.nakedSingle:
        return _nakedSingle();
      case Strategy.hiddenSingle:
        return _hiddenSingle();
      case Strategy.lockedCandidates:
        return _lockedCandidates();
      case Strategy.nakedPair:
        return _nakedSubset(2);
      case Strategy.hiddenPair:
        return _hiddenSubset(2);
      case Strategy.nakedTriple:
        return _nakedSubset(3);
      case Strategy.hiddenTriple:
        return _hiddenSubset(3);
      case Strategy.xWing:
        return _fish(2);
      case Strategy.swordfish:
        return _fish(3);
      case Strategy.xyWing:
        return _xyWing();
    }
  }

  List<int> _cellsWith(List<int> unit, int d) {
    final b = 1 << d;
    return [for (final c in unit) if (values[c] == 0 && cand[c] & b != 0) c];
  }

  bool _placedIn(List<int> unit, int d) {
    for (final c in unit) {
      if (values[c] == d) return true;
    }
    return false;
  }

  // ------------------------------------------------------------ strategies --

  bool _nakedSingle() {
    for (var c = 0; c < cellCount; c++) {
      if (values[c] == 0 && bitCount(cand[c]) == 1) {
        _place(c, firstDigit(cand[c]));
        return true;
      }
    }
    return false;
  }

  bool _hiddenSingle() {
    for (final unit in units) {
      for (var d = 1; d <= 9; d++) {
        if (_placedIn(unit, d)) continue;
        final cells = _cellsWith(unit, d);
        if (cells.length == 1) {
          _place(cells.first, d);
          return true;
        }
      }
    }
    return false;
  }

  bool _lockedCandidates() {
    // Pointing: inside a box, all candidates of d lie in one row/column.
    for (var b = 0; b < 9; b++) {
      final box = units[18 + b];
      for (var d = 1; d <= 9; d++) {
        final cells = _cellsWith(box, d);
        if (cells.length < 2) continue;
        final r = rowOf(cells.first), k = colOf(cells.first);
        var changed = false;
        if (cells.every((c) => rowOf(c) == r)) {
          for (final c in units[r]) {
            if (boxOf(c) != b) changed |= _elim(c, 1 << d);
          }
        } else if (cells.every((c) => colOf(c) == k)) {
          for (final c in units[9 + k]) {
            if (boxOf(c) != b) changed |= _elim(c, 1 << d);
          }
        }
        if (changed) return true;
      }
    }
    // Claiming: inside a row/column, all candidates of d lie in one box.
    for (var u = 0; u < 18; u++) {
      final line = units[u];
      for (var d = 1; d <= 9; d++) {
        final cells = _cellsWith(line, d);
        if (cells.length < 2) continue;
        final b = boxOf(cells.first);
        if (!cells.every((c) => boxOf(c) == b)) continue;
        var changed = false;
        for (final c in units[18 + b]) {
          if (!line.contains(c)) changed |= _elim(c, 1 << d);
        }
        if (changed) return true;
      }
    }
    return false;
  }

  /// Naked pair (n=2) / triple (n=3): n cells of a unit whose candidates
  /// together contain exactly n digits.
  bool _nakedSubset(int n) {
    for (final unit in units) {
      final open = [
        for (final c in unit)
          if (values[c] == 0 && bitCount(cand[c]) >= 2 && bitCount(cand[c]) <= n) c,
      ];
      if (open.length < n) continue;
      for (final combo in _combinations(open, n)) {
        var union = 0;
        for (final c in combo) {
          union |= cand[c];
        }
        if (bitCount(union) != n) continue;
        var changed = false;
        for (final c in unit) {
          if (!combo.contains(c)) changed |= _elim(c, union);
        }
        if (changed) return true;
      }
    }
    return false;
  }

  /// Hidden pair (n=2) / triple (n=3): n digits of a unit that only fit into
  /// the same n cells; all other digits leave those cells.
  bool _hiddenSubset(int n) {
    for (final unit in units) {
      final digits = <int>[];
      final where = <int, List<int>>{};
      for (var d = 1; d <= 9; d++) {
        if (_placedIn(unit, d)) continue;
        final cells = _cellsWith(unit, d);
        if (cells.length >= 2 && cells.length <= n) {
          digits.add(d);
          where[d] = cells;
        }
      }
      if (digits.length < n) continue;
      for (final combo in _combinations(digits, n)) {
        final cells = <int>{};
        var mask = 0;
        for (final d in combo) {
          cells.addAll(where[d]!);
          mask |= 1 << d;
        }
        if (cells.length != n) continue;
        var changed = false;
        for (final c in cells) {
          changed |= _elim(c, allDigits & ~mask);
        }
        if (changed) return true;
      }
    }
    return false;
  }

  /// X-Wing (n=2) and Swordfish (n=3), row- and column-based.
  bool _fish(int n) {
    for (var d = 1; d <= 9; d++) {
      for (final rowBased in [true, false]) {
        // base lines and the cross positions of d in each
        final lines = <int>[];
        final pos = <int, Set<int>>{};
        for (var i = 0; i < 9; i++) {
          final line = units[rowBased ? i : 9 + i];
          if (_placedIn(line, d)) continue;
          final cells = _cellsWith(line, d);
          if (cells.length >= 2 && cells.length <= n) {
            lines.add(i);
            pos[i] = {for (final c in cells) rowBased ? colOf(c) : rowOf(c)};
          }
        }
        if (lines.length < n) continue;
        for (final combo in _combinations(lines, n)) {
          final cover = <int>{};
          for (final i in combo) {
            cover.addAll(pos[i]!);
          }
          if (cover.length != n) continue;
          var changed = false;
          for (final x in cover) {
            final crossLine = units[rowBased ? 9 + x : x];
            for (final c in crossLine) {
              final base = rowBased ? rowOf(c) : colOf(c);
              if (!combo.contains(base)) changed |= _elim(c, 1 << d);
            }
          }
          if (changed) return true;
        }
      }
    }
    return false;
  }

  bool _xyWing() {
    final bivalue = [
      for (var c = 0; c < cellCount; c++)
        if (values[c] == 0 && bitCount(cand[c]) == 2) c,
    ];
    for (final pivot in bivalue) {
      final pm = cand[pivot];
      final wings = [for (final p in peers[pivot]) if (bivalue.contains(p)) p];
      for (var i = 0; i < wings.length; i++) {
        final a = wings[i];
        final am = cand[a];
        final sharedA = am & pm;
        if (bitCount(sharedA) != 1 || am == pm) continue;
        final z = am & ~pm; // the digit the pincer adds
        for (var j = 0; j < wings.length; j++) {
          if (i == j) continue;
          final b = wings[j];
          final bm = cand[b];
          // b must hold the other pivot digit plus the same z
          if (bm != ((pm & ~sharedA) | z)) continue;
          var changed = false;
          for (final c in peers[a]) {
            if (c != b && c != pivot && peers[b].contains(c)) {
              changed |= _elim(c, z);
            }
          }
          if (changed) return true;
        }
      }
    }
    return false;
  }
}

/// All n-element combinations of [items], preserving order.
Iterable<List<T>> _combinations<T>(List<T> items, int n) sync* {
  final idx = List<int>.generate(n, (i) => i);
  if (items.length < n) return;
  while (true) {
    yield [for (final i in idx) items[i]];
    var k = n - 1;
    while (k >= 0 && idx[k] == items.length - n + k) {
      k--;
    }
    if (k < 0) return;
    idx[k]++;
    for (var m = k + 1; m < n; m++) {
      idx[m] = idx[m - 1] + 1;
    }
  }
}

/// Solves [puzzle] with the strategies of [level] only.
LogicResult solveLogically(List<int> puzzle, Difficulty level, {List<int>? oracle}) =>
    LogicSolver(puzzle, oracle: oracle).run(level.allowedStrategies);

class Rating {
  Rating(this.level, this.result);

  /// Lowest level whose strategies solve the puzzle; null = beyond expert.
  final Difficulty? level;
  final LogicResult result;
}

/// Master-Prompt 6.1: the puzzle gets the lowest level whose solver solves it.
Rating rate(List<int> puzzle, {List<int>? oracle}) {
  LogicResult? last;
  for (final level in Difficulty.values) {
    final r = solveLogically(puzzle, level, oracle: oracle);
    last = r;
    if (r.solved) return Rating(level, r);
  }
  return Rating(null, last!);
}
