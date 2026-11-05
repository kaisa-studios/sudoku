/// Exact backtracking solver with bit masks and minimum-remaining-values.
///
/// Used to prove uniqueness (stops at the second solution) and to fill
/// random complete grids. It is intentionally independent from the logical
/// rater so both can check each other in tests.
library;

import 'dart:math';

import 'grid.dart';

class _Search {
  _Search(List<int> start, this.limit, this.rng) : cells = List.of(start) {
    for (var c = 0; c < cellCount; c++) {
      final v = cells[c];
      if (v == 0) continue;
      final b = 1 << v;
      final r = rowOf(c), k = colOf(c), x = boxOf(c);
      if ((rows[r] | cols[k] | boxes[x]) & b != 0) {
        conflict = true;
      }
      rows[r] |= b;
      cols[k] |= b;
      boxes[x] |= b;
    }
  }

  final List<int> cells;
  final int limit;
  final Random? rng;
  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);
  bool conflict = false;
  int found = 0;
  List<int>? first;
  int nodes = 0;
  int maxNodes = 2000000;

  void run() {
    if (conflict) return;
    _step();
  }

  bool _step() {
    if (++nodes > maxNodes) return true; // give up (treated as "not unique")
    // choose empty cell with fewest candidates
    var best = -1, bestCount = 10, bestMask = 0;
    for (var c = 0; c < cellCount; c++) {
      if (cells[c] != 0) continue;
      final used = rows[rowOf(c)] | cols[colOf(c)] | boxes[boxOf(c)];
      final mask = allDigits & ~used;
      final n = bitCount(mask);
      if (n < bestCount) {
        best = c;
        bestCount = n;
        bestMask = mask;
        if (n <= 1) break;
      }
    }
    if (best < 0) {
      found++;
      first ??= List.of(cells);
      return found >= limit;
    }
    if (bestCount == 0) return false;
    final digits = digitsOf(bestMask);
    if (rng != null) digits.shuffle(rng);
    final r = rowOf(best), k = colOf(best), x = boxOf(best);
    for (final d in digits) {
      final b = 1 << d;
      cells[best] = d;
      rows[r] |= b;
      cols[k] |= b;
      boxes[x] |= b;
      final stop = _step();
      rows[r] &= ~b;
      cols[k] &= ~b;
      boxes[x] &= ~b;
      cells[best] = 0;
      if (stop) return true;
    }
    return false;
  }
}

/// Number of solutions, counting at most [limit] (default 2 = "is it unique?").
/// Returns [limit] if the search budget is exhausted, so a timeout never
/// passes as "unique".
int countSolutions(List<int> grid, {int limit = 2}) {
  final s = _Search(grid, limit, null)..run();
  if (s.nodes > s.maxNodes) return limit;
  return s.found;
}

bool hasUniqueSolution(List<int> grid) => countSolutions(grid) == 1;

/// One solution or null.
List<int>? solve(List<int> grid) {
  final s = _Search(grid, 1, null)..run();
  return s.first;
}

/// A random complete valid grid.
List<int> randomSolution(Random rng) {
  final s = _Search(List.filled(cellCount, 0), 1, rng)..run();
  return s.first!;
}
