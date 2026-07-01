import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/ad_service.dart';
import 'services/auto_updater.dart';
import 'services/catalog_db.dart';
import 'services/rongyok_client.dart';
import 'services/settings_store.dart';
import 'state/app_state.dart';
import 'state/catalog_state.dart';
import 'theme/app_theme.dart';

/// Lets screens refresh when a pushed route (e.g. the player) pops back —
/// used by Home to reload "Continue watching".
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  final settings = await SettingsStore.load();
  final client = RongYokClient();
  final db = await CatalogDb.open();

  runApp(HiveApp(settings: settings, client: client, db: db));
}

class HiveApp extends StatelessWidget {
  const HiveApp({super.key, required this.settings, required this.client, required this.db});

  final SettingsStore settings;
  final RongYokClient client;
  final CatalogDb db;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(settings)),
        ChangeNotifierProvider(create: (_) => CatalogState(client, db)),
        // Ad delivery (main.thaiprompt.online). Starts fetching+rotating now;
        // a silent no-op until the ad backend goes live.
        ChangeNotifierProvider(create: (_) => AdService()..start(placements: const ['player', 'home'])),
        Provider<RongYokClient>(create: (_) => client),
        Provider<CatalogDb>(create: (_) => db),
        Provider<AutoUpdater>(create: (_) => AutoUpdater()),
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) => MaterialApp(
          title: 'Hive Download',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          navigatorObservers: [routeObserver],
          home: app.onboarded ? const AppShell() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
