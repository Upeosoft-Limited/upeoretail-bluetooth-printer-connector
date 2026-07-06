import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../models/receipt.dart';
import '../services/printer_service.dart';
import '../services/settings_store.dart';
import '../widgets/error_view.dart';
import 'printer_settings_screen.dart';

/// Main screen: hosts the UpeoRetail web app and bridges print requests to the
/// native Bluetooth printer.
class WebViewScreen extends StatefulWidget {
  final SettingsStore store;
  final PrinterService printer;
  const WebViewScreen({super.key, required this.store, required this.printer});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;
  bool _refreshing = false;

  // Pull-to-refresh bookkeeping (drag tracking + at-top check).
  double _pullStartY = 0;
  bool _checkingTop = false;
  bool _printing = false;

  SettingsStore get store => widget.store;
  PrinterService get printer => widget.printer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(AppConfig.jsChannel, onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() {
          _hasError = false;
          _progress = 0;
        }),
        onPageFinished: (_) async {
          setState(() => _progress = 100);
          await _injectHelper();
        },
        onWebResourceError: (err) {
          // Ignore subresource errors; only flag a failed main-frame load.
          if (err.isForMainFrame ?? true) setState(() => _hasError = true);
        },
      ))
      ..loadRequest(Uri.parse(store.webUrl));
  }

  /// True when the page is scrolled to the very top (for pull-to-refresh).
  Future<bool> _isAtTop() async {
    try {
      final res = await _controller.runJavaScriptReturningResult('window.scrollY');
      return (double.tryParse(res.toString()) ?? 1) <= 0.5;
    } catch (_) {
      return false;
    }
  }

  /// Make `window.printReceipt(...)` available even if the web app hasn't added
  /// it yet. It simply forwards to the native channel.
  Future<void> _injectHelper() async {
    const js = '''
      window.printReceipt = window.printReceipt || function(receipt) {
        try {
          window.${AppConfig.jsChannel}.postMessage(
            JSON.stringify({ type: "${AppConfig.printType}", payload: receipt }));
          return true;
        } catch (e) { return false; }
      };
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {/* page may have navigated; ignore */}
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    await _controller.reload();
    if (mounted) setState(() => _refreshing = false);
  }

  // -------------------------------------------------------------------------
  // JavaScript bridge
  // -------------------------------------------------------------------------
  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    // Security: only honour messages from the configured UpeoRetail domain.
    final current = await _controller.currentUrl();
    final host = current == null ? null : Uri.tryParse(current)?.host;
    if (!AppConfig.isAllowedHost(host)) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return; // not JSON — ignore
    }

    if (data['type'] != AppConfig.printType) return; // unknown type — ignore

    final payload = data['payload'];
    if (payload is! Map) {
      _snack('Invalid receipt data.', error: true);
      return;
    }

    final receipt = Receipt.fromJson(Map<String, dynamic>.from(payload));
    final problem = receipt.validate();
    if (problem != null) {
      _snack(problem, error: true);
      return;
    }

    await _print(receipt);
  }

  Future<void> _print(Receipt receipt) async {
    if (_printing) return;
    _printing = true;
    _snack('Printing…');
    try {
      await printer.printReceipt(receipt);
      _snack('Printed ${receipt.invoiceNo}');
    } on NoPrinterSelected {
      await _promptChoosePrinter();
    } on BluetoothOff {
      _snack('Bluetooth is off. Turn it on and try again.', error: true);
    } on PermissionDenied {
      _snack('Bluetooth permission denied. Enable it in app settings.', error: true);
    } on PrinterException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack('Printing failed: $e', error: true);
    } finally {
      _printing = false;
    }
  }

  Future<void> _promptChoosePrinter() async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a printer'),
        content: const Text(
            'No default printer is selected yet. Open printer settings to pick your '
            'Bluetooth thermal printer (e.g. P58E).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
        ],
      ),
    );
    if (go == true) _openSettings();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrinterSettingsScreen(store: store, printer: printer),
    ));
    // The URL may have changed in settings — load the (possibly new) saved URL
    // so a saved change takes effect immediately without a manual reload.
    if (!mounted) return;
    final current = await _controller.currentUrl();
    final saved = store.webUrl;
    final currentHost = current == null ? null : Uri.tryParse(current)?.host;
    final savedHost = Uri.tryParse(saved)?.host;
    if (current == null || currentHost != savedHost) {
      await _controller.loadRequest(Uri.parse(saved));
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Printer settings'),
              onTap: () {
                Navigator.pop(ctx);
                _openSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reload page'),
              onTap: () {
                Navigator.pop(ctx);
                _reload();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
        duration: Duration(seconds: error ? 4 : 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final loading = _progress < 100 || _refreshing;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_hasError)
              ErrorView(
                message: 'Check your internet connection and try again.',
                onRetry: _reload,
              )
            else
              // Listener detects a downward pull at the top without stealing the
              // WebView's own scroll gestures.
              Listener(
                onPointerDown: (e) => _pullStartY = e.position.dy,
                onPointerMove: (e) async {
                  // A clear downward pull — confirm we're at the top before reloading.
                  if (_refreshing ||
                      _checkingTop ||
                      (e.position.dy - _pullStartY) <= 150) {
                    return;
                  }
                  _checkingTop = true;
                  final atTop = await _isAtTop();
                  _checkingTop = false;
                  if (atTop && !_refreshing) {
                    _pullStartY = e.position.dy;
                    _reload();
                  }
                },
                child: WebViewWidget(controller: _controller),
              ),
            if (loading && !_hasError)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _openMenu,
        tooltip: 'Menu',
        child: const Icon(Icons.print),
      ),
    );
  }
}
