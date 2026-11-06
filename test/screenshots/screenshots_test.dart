// Renders real app screens to PNG for the store screenshots (German and English).
// Runs only with SCREENSHOTS=1 (see .github/workflows/screenshots.yml), which also
// provides FONT_DIR with Flutter's bundled Roboto and Material icon fonts.
// The frames with headlines are composed afterwards by tool/store_screens.py.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/app/services.dart';
import 'package:sudoku/data/entitlement_repository.dart';
import 'package:sudoku/data/game_repository.dart';
import 'package:sudoku/data/puzzle_content.dart';
import 'package:sudoku/domain/daily/streak.dart';
import 'package:sudoku/domain/game/game.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/grid.dart';
import 'package:sudoku/features/ads/ad_coordinator.dart';
import 'package:sudoku/features/ads/ads_backend.dart';
import 'package:sudoku/features/purchases/purchase_controller.dart';
import 'package:sudoku/features/purchases/store.dart';
import 'package:sudoku/features/purchases/verifier.dart';
import 'package:sudoku/main.dart';

import '../support.dart';

final enabled = Platform.environment['SCREENSHOTS'] == '1';
final outDir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';

Future<void> loadFonts() async {
  final dir = Platform.environment['FONT_DIR'];
  if (dir == null) return;
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await family('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Light.ttf']);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> settle(WidgetTester tester, {int frames = 15}) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _shotKey = GlobalKey();

Future<void> shot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$outDir/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

/// Fills every empty cell with its solution (a solved game).
void solve(Game g) {
  for (var c = 0; c < cellCount; c++) {
    if (g.values[c] == 0) {
      g.select(c);
      g.enter(g.solution[c]);
    }
  }
}

/// Digits still possible in an empty cell, from the visible board.
List<int> candidates(Game g, int cell) => [
      for (var d = 1; d <= 9; d++)
        if (peers[cell].every((p) => g.values[p] != d)) d,
    ];

void main() {
  testWidgets('store screenshots', skip: !enabled, (tester) async {
    tester.view.physicalSize = const Size(1179, 2556); // 393 x 852 pt @3x
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await loadFonts();
      final content = PuzzleContent.parse(
        File('assets/puzzles/pool.json').readAsStringSync(),
        File('assets/puzzles/daily.json').readAsStringSync(),
      );

      for (final lang in ['de', 'en']) {
        var now = DateTime(2026, 11, 16, 9);
        final db = memoryDb();
        final games = GameRepository(db, clock: () => now);
        final purchases = PurchaseController(
          store: DemoStoreGateway(delay: Duration.zero),
          verifier: const DemoVerifier(),
          entitlements: EntitlementRepository(db),
          settings: games,
          restoreSettle: Duration.zero,
        );
        final ads = AdCoordinator(backend: const NoAdsBackend(), store: games, purchases: purchases, enabled: false);
        final services = Services(
          games: games,
          content: content,
          purchases: purchases,
          ads: ads,
          source: (level, avoid) async => content.pool(level)[3],
          clock: () => now,
        );
        await services.settings.setLanguage(lang);

        // history: daily puzzles on four earlier days and two today, some regular games
        final times = [312, 468, 401, 655, 287, 530, 742, 389];
        var t = 0;
        for (var day = 16; day <= 20; day++) {
          now = DateTime(2026, 11, day, 8);
          final slots = day == 20 ? [0, 1] : [0, if (day.isEven) 1];
          for (final slot in slots) {
            final s = await games.startDaily(content.dailyFor(now)![slot], dayKey(now), slot);
            solve(s.game);
            s.game.activeMs = times[t++ % times.length] * 1000;
            await games.save(s);
          }
          if (day < 20) {
            final s = await games.startRegular(content.pool(Difficulty.values[day % 4])[day]);
            solve(s.game);
            s.game.activeMs = times[(t++ + 3) % times.length] * 1500;
            await games.save(s);
          }
        }
        now = DateTime(2026, 11, 20, 18, 30);

        // the open game: medium, about half done, a few notes, one mistake
        final open = await games.startRegular(content.pool(Difficulty.medium)[7]);
        final g = open.game;
        final empty = [for (var c = 0; c < cellCount; c++) if (g.values[c] == 0) c];
        for (var i = 0; i < empty.length; i++) {
          if (i % 5 < 3) {
            g.select(empty[i]);
            g.enter(g.solution[empty[i]]);
          }
        }
        final rest = [for (final c in empty) if (g.values[c] == 0) c];
        g.toggleNotesMode();
        for (final c in rest.take(4)) {
          g.select(c);
          for (final d in candidates(g, c).take(3)) {
            g.enter(d);
          }
        }
        g.toggleNotesMode();
        g.mistakes = 1;
        g.activeMs = 252000;
        g.select(rest[6]);
        await games.save(open);
        await purchases.start();

        Widget app() => RepaintBoundary(key: _shotKey, child: TidySudokuApp(services: services));

        await tester.pumpWidget(app());
        await settle(tester, frames: 30);
        await shot(tester, '${lang}_1_start');

        // game
        await tester.tap(find.byIcon(Icons.play_arrow).first);
        await settle(tester, frames: 25);
        await shot(tester, '${lang}_2_spiel');

        // large view
        await tester.tap(find.byTooltip(lang == 'de' ? 'Große Darstellung' : 'Large view'));
        await settle(tester, frames: 15);
        await shot(tester, '${lang}_5_gross');
        await tester.tap(find.byTooltip(lang == 'de' ? 'Ganzes Raster' : 'Whole grid'));
        await settle(tester, frames: 10);

        // dark mode game
        await services.settings.setThemeMode(ThemeMode.dark);
        await settle(tester, frames: 20);
        await shot(tester, '${lang}_4_dunkel');
        await services.settings.setThemeMode(ThemeMode.light);
        await tester.tap(find.byType(BackButton));
        await settle(tester, frames: 20);

        // daily puzzles
        await tester.tap(find.bySemanticsLabel(RegExp(lang == 'de' ? '^Tägliches Sudoku' : '^Daily Sudoku')));
        await settle(tester, frames: 20);
        await shot(tester, '${lang}_3_taeglich');
        await tester.tap(find.byType(BackButton));
        await settle(tester, frames: 20);

        // statistics
        final stats = find.text(lang == 'de' ? 'Statistik' : 'Statistics');
        await tester.ensureVisible(stats);
        await settle(tester, frames: 5);
        await tester.tap(stats);
        await settle(tester, frames: 20);
        await shot(tester, '${lang}_6_statistik');

        await tester.pumpWidget(const SizedBox());
        await settle(tester, frames: 3);
        await db.close();
      }
    });
  });
}
