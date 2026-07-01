import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/ad_service.dart';
import 'services/auto_updater.dart';
import 'services/rongyok_client.dart';
import 'services/settings_store.dart';
import 'state/app_state.dart';
import 'state/catalog_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  final settings = await SettingsStore.load();
  final client = RongYokClient();

  runApp(HiveApp(settings: settings, client: client));
}

class HiveApp extends StatelessWidget {
  const HiveApp({super.key, required this.settings, required this.client});

  final SettingsStore settings;
  final RongYokClient client;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(settings)),
        ChangeNotifierProvider(create: (_) => CatalogState(client)),
        // Ad delivery (main.thaiprompt.online). Starts fetching+rotating now;
        // a silent no-op until the ad backend goes live.
        ChangeNotifierProvider(create: (_) => AdService()..start(placements: const ['player', 'home'])),
        Provider<RongYokClient>(create: (_) => client),
        Provider<AutoUpdater>(create: (_) => AutoUpdater()),
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) => MaterialApp(
          title: 'Hive Download',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: app.onboarded ? const AppShell() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
