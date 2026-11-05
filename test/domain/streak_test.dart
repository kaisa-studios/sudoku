import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/daily/streak.dart';

void main() {
  final today = DateTime(2026, 11, 10, 9);

  test('no days: no streak', () {
    final s = computeStreak({}, today);
    expect(s.current, 0);
    expect(s.best, 0);
    expect(s.todayDone, isFalse);
  });

  test('streak includes today when done', () {
    final s = computeStreak({'2026-11-08', '2026-11-09', '2026-11-10'}, today);
    expect(s.current, 3);
    expect(s.best, 3);
    expect(s.todayDone, isTrue);
  });

  test('streak stays alive until today is over', () {
    final s = computeStreak({'2026-11-08', '2026-11-09'}, today);
    expect(s.current, 2);
    expect(s.todayDone, isFalse);
  });

  test('a missed day resets the current streak, best stays', () {
    final s = computeStreak({'2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-08'}, today);
    expect(s.current, 0);
    expect(s.best, 4);
  });

  test('month and daylight-saving boundaries', () {
    final s = computeStreak({'2026-10-24', '2026-10-25', '2026-10-26'}, DateTime(2026, 10, 26, 23));
    expect(s.current, 3);
    final m = computeStreak({'2026-11-30', '2026-12-01'}, DateTime(2026, 12, 1));
    expect(m.current, 2);
  });

  test('day key is zero padded', () {
    expect(dayKey(DateTime(2027, 1, 5)), '2027-01-05');
  });
}
