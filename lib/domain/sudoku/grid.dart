/// Basic geometry of the classic 9x9 Sudoku grid.
///
/// Cells are addressed by index 0..80 (row-major). A grid is a list of 81 ints,
/// 0 = empty, 1..9 = digit. Candidate sets are bit masks where bit `d` (1..9)
/// means digit `d` is possible; [allDigits] has bits 1..9 set.
library;

const int cellCount = 81;
const int allDigits = 0x3FE; // bits 1..9

int rowOf(int cell) => cell ~/ 9;
int colOf(int cell) => cell % 9;
int boxOf(int cell) => (cell ~/ 27) * 3 + (cell % 9) ~/ 3;

/// The 27 units: rows 0..8, columns 9..17, boxes 18..26.
final List<List<int>> units = _buildUnits();

/// For each cell the three units it belongs to (row, column, box).
final List<List<int>> unitsOfCell = List.generate(
  cellCount,
  (c) => [rowOf(c), 9 + colOf(c), 18 + boxOf(c)],
  growable: false,
);

/// For each cell the 20 other cells sharing a row, column or box.
final List<List<int>> peers = List.generate(cellCount, (c) {
  final set = <int>{};
  for (final u in unitsOfCell[c]) {
    set.addAll(units[u]);
  }
  set.remove(c);
  return set.toList()..sort();
}, growable: false);

List<List<int>> _buildUnits() {
  final out = <List<int>>[];
  for (var r = 0; r < 9; r++) {
    out.add([for (var c = 0; c < 9; c++) r * 9 + c]);
  }
  for (var c = 0; c < 9; c++) {
    out.add([for (var r = 0; r < 9; r++) r * 9 + c]);
  }
  for (var b = 0; b < 9; b++) {
    final r0 = (b ~/ 3) * 3, c0 = (b % 3) * 3;
    out.add([
      for (var r = r0; r < r0 + 3; r++)
        for (var c = c0; c < c0 + 3; c++) r * 9 + c,
    ]);
  }
  return out;
}

int bitOf(int digit) => 1 << digit;

int bitCount(int mask) {
  var n = 0;
  var m = mask;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

/// Digits contained in a candidate mask, ascending.
List<int> digitsOf(int mask) => [
      for (var d = 1; d <= 9; d++)
        if (mask & (1 << d) != 0) d,
    ];

/// Lowest digit in a non-empty mask.
int firstDigit(int mask) {
  for (var d = 1; d <= 9; d++) {
    if (mask & (1 << d) != 0) return d;
  }
  return 0;
}

/// Checks length, value range and that no unit contains a digit twice.
/// Empty cells are allowed.
bool isValidGrid(List<int> grid) {
  if (grid.length != cellCount) return false;
  for (final v in grid) {
    if (v < 0 || v > 9) return false;
  }
  for (final unit in units) {
    var seen = 0;
    for (final c in unit) {
      final v = grid[c];
      if (v == 0) continue;
      final b = 1 << v;
      if (seen & b != 0) return false;
      seen |= b;
    }
  }
  return true;
}

/// True if the grid is completely filled and valid.
bool isSolvedGrid(List<int> grid) => isValidGrid(grid) && !grid.contains(0);

/// Compact 81-character form ("0" for empty), used as fingerprint and in tests.
String gridToString(List<int> grid) => grid.join();

List<int> gridFromString(String s) {
  final clean = s.replaceAll(RegExp(r'\s'), '').replaceAll('.', '0');
  if (clean.length != cellCount) {
    throw FormatException('expected 81 cells, got ${clean.length}');
  }
  return [for (final ch in clean.split('')) int.parse(ch)];
}
