import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/config.dart';
import 'app/services.dart';
import 'app/theme.dart';
import 'data/app_database.dart';
import 'data/entitlement_repository.dart';
import 'data/game_repository.dart';
import 'data/puzzle_content.dart';
import 'features/ads/ad_coordinator.dart';
import 'features/ads/ads_backend.dart';
import 'features/home/home_screen.dart';
import 'features/purchases/purchase_controller.dart';
import 'l10n/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final games = GameRepository(db);
  final purchases = PurchaseController(
    store: defaultStore(),
    verifier: defaultVerifier(),
    entitlements: EntitlementRepository(db),
    settings: games,
  );
  final ads = AdCoordinator(
    backend: AppConfig.adsEnabled ? GoogleAdsBackend() : const NoAdsBackend(),
    store: games,
    purchases: purchases,
  );
  final services = Services(
    games: games,
    content: await PuzzleContent.load(rootBundle),
    purchases: purchases,
    ads: ads,
  );
  await services.settings.load();
  runApp(TidySudokuApp(services: services));
  // ads wait for the locally stored purchase (no ad before the ad-free status is known),
  // then consent (UMP, every start), then the SDK
  unawaited(ads.start());
  unawaited(purchases.start());
}

class TidySudokuApp extends StatelessWidget {
  const TidySudokuApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => context.s.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: services.settings.themeMode,
          // null follows the device; other languages than German/English fall back to English (D8)
          locale: services.settings.locale,
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [AppStringsDelegate(), ...GlobalMaterialLocalizations.delegates],
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
