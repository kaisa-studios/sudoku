import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/services.dart';
import '../purchases/purchase_controller.dart';
import '../../l10n/strings.dart';
import '../../app/version.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<PurchaseMessage>? _messages;

  @override
  void initState() {
    super.initState();
    _messages = ServicesScope.read(context).purchases.messages.listen((m) {
      if (!mounted) return;
      final s = context.s;
      final text = switch (m) {
        PurchaseMessage.unlocked => s.msgUnlocked,
        PurchaseMessage.canceled => s.msgCanceled,
        PurchaseMessage.failed => s.msgFailed,
        PurchaseMessage.verificationFailed => s.msgVerificationFailed,
        PurchaseMessage.paidUnverified => s.msgPaidUnverified,
        PurchaseMessage.checkUnavailable => s.msgCheckUnavailable,
        PurchaseMessage.restoredOwned => s.msgRestoredOwned,
        PurchaseMessage.restoredNothing => s.msgRestoredNothing,
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
  }

  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s.linkFailed)));
    }
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  Future<void> _deleteData(BuildContext context) async {
    final s = context.s;
    final services = ServicesScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteConfirmTitle),
        content: Text(s.deleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await services.games.deleteAllGameData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deleteDone)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final services = context.services;
    final settings = services.settings;
    final text = Theme.of(context).textTheme;
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(t, style: text.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([settings, services.purchases, services.ads]),
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(children: [
                heading(s.appearance),
                RadioGroup<ThemeMode>(
                  groupValue: settings.themeMode,
                  onChanged: (m) => settings.setThemeMode(m ?? ThemeMode.system),
                  child: Column(children: [
                    RadioListTile<ThemeMode>(value: ThemeMode.system, title: Text(s.themeSystem)),
                    RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text(s.themeLight)),
                    RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text(s.themeDark)),
                  ]),
                ),
                heading(s.language),
                RadioGroup<String>(
                  groupValue: settings.languageCode ?? 'device',
                  onChanged: (v) => settings.setLanguage(v == 'de' || v == 'en' ? v : null),
                  child: Column(children: [
                    RadioListTile<String>(value: 'device', title: Text(s.languageDevice)),
                    const RadioListTile<String>(value: 'de', title: Text('Deutsch')),
                    const RadioListTile<String>(value: 'en', title: Text('English')),
                  ]),
                ),
                heading(s.gameHeading),
                SwitchListTile(
                  value: settings.showTimer,
                  onChanged: settings.setShowTimer,
                  title: Text(s.showTimer),
                ),
                SwitchListTile(
                  value: settings.haptics,
                  onChanged: settings.setHaptics,
                  title: Text(s.haptics),
                  subtitle: Text(s.hapticsHint),
                ),
                SwitchListTile(
                  value: settings.largeViewDefault,
                  onChanged: settings.setLargeViewDefault,
                  title: Text(s.largeViewDefault),
                  subtitle: Text(s.largeViewHint),
                ),
                heading(s.removeAdsHeading),
                _RemoveAds(purchases: services.purchases),
                if (services.ads.privacyOptionsRequired)
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(s.privacyOptions),
                    onTap: services.ads.showPrivacyOptions,
                  ),
                heading(s.dataHeading),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(s.localStorageNote, style: text.bodyMedium),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: Text(s.deleteData),
                  subtitle: Text(s.deleteDataHint),
                  onTap: () => _deleteData(context),
                ),
                heading(s.aboutHeading),
                ListTile(
                  leading: const Icon(Icons.policy_outlined),
                  title: Text(s.privacyPolicy),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(AppConfig.privacyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(s.supportAndImprint),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(AppConfig.supportUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(s.licenses),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: s.appTitle,
                    applicationVersion: appVersion,
                    applicationLegalese: '© 2026 Kaisa',
                  ),
                ),
                const Divider(),
                ListTile(title: Text(s.version(appVersion))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Werbung entfernen": offer, live store price, purchase states, restore (10.5, 10.7).
class _RemoveAds extends StatelessWidget {
  // takes the controller so it rebuilds with the surrounding ListenableBuilder
  const _RemoveAds({required this.purchases});

  final PurchaseController purchases;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = purchases;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final state = p.state;
    if (state == RemoveAdsState.owned) {
      return ListTile(
        leading: Icon(Icons.check_circle, color: scheme.primary),
        title: Text(s.removeAdsOwned),
      );
    }
    final note = switch (state) {
      RemoveAdsState.pending => s.purchasePending,
      RemoveAdsState.verifying => p.paidUnverified ? s.paidUnverifiedNote : s.purchaseVerifying,
      RemoveAdsState.revoked => s.revokedNote,
      _ => null,
    };
    final product = p.product;
    Widget action;
    if (p.paidUnverified) {
      action = FilledButton(onPressed: p.restoring ? null : p.restore, child: Text(s.checkAgain));
    } else if (state == RemoveAdsState.unknown || p.productsLoading) {
      action = const Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)));
    } else if (product == null) {
      action = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.storeUnavailable, style: text.bodyLarge),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: p.loadProducts, child: Text(s.tryAgain)),
      ]);
    } else {
      action = FilledButton(
        onPressed: p.busy || p.restoring ? null : p.buy,
        child: p.busy
            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
            : Text(s.buyFor(product.price)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.removeAdsOffer, style: text.bodyLarge),
        if (note != null) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(note, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
        ],
        const SizedBox(height: 12),
        action,
        const SizedBox(height: 4),
        TextButton(onPressed: p.restoring || p.busy ? null : p.restore, child: Text(s.restorePurchases)),
        if (p.isDemo) Text(s.demoStoreNote, style: text.bodyMedium),
      ]),
    );
  }
}
