/// Daily streak (DECISIONS D7): a day counts when at least one daily puzzle
/// of that day was finished. Days are local calendar days as yyyy-mm-dd.
library;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]); // UTC: no daylight-saving gaps
}

class Streak {
  const Streak({required this.current, required this.best, required this.todayDone});

  /// Consecutive days up to today; if today is not done yet, up to yesterday
  /// (the streak is still alive until the day is over).
  final int current;
  final int best;
  final bool todayDone;
}

Streak computeStreak(Set<String> doneDays, DateTime today) {
  final todayKey = dayKey(today);
  final todayDone = doneDays.contains(todayKey);
  var cursor = _day(todayKey);
  if (!todayDone) cursor = cursor.subtract(const Duration(days: 1));
  var current = 0;
  while (doneDays.contains(dayKey(cursor))) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  final sorted = doneDays.map(_day).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return Streak(current: current, best: best, todayDone: todayDone);
}
