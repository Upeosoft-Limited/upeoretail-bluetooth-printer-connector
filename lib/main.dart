import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/webview_screen.dart';
import 'services/printer_service.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.create();
  final printer = PrinterService(store);
  runApp(UpeoRetailPrintApp(store: store, printer: printer));
}

class UpeoRetailPrintApp extends StatelessWidget {
  final SettingsStore store;
  final PrinterService printer;
  const UpeoRetailPrintApp({super.key, required this.store, required this.printer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(AppConfig.brandColor),
      ),
      home: WebViewScreen(store: store, printer: printer),
    );
  }
}
