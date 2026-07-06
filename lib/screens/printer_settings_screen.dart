import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../services/printer_service.dart';
import '../services/settings_store.dart';

/// Settings: web URL, paper size, paired-printer selection, connection status
/// and a test print.
class PrinterSettingsScreen extends StatefulWidget {
  final SettingsStore store;
  final PrinterService printer;
  const PrinterSettingsScreen({super.key, required this.store, required this.printer});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late final TextEditingController _urlCtrl =
      TextEditingController(text: widget.store.webUrl);

  List<BluetoothInfo> _printers = [];
  bool _loading = false;
  bool _bluetoothOn = false;
  bool _connected = false;
  String? _error;

  SettingsStore get store => widget.store;
  PrinterService get printer => widget.printer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _bluetoothOn = await printer.isBluetoothOn();
      _printers = await printer.pairedPrinters();
      // If a default printer is set but the socket isn't up, reconnect quietly
      // so the status reflects reality and the next print is instant.
      if (store.hasPrinter && _bluetoothOn) {
        try {
          await printer.ensureConnectedToDefault();
        } catch (_) {/* status row will show "Not connected" */}
      }
      _connected = await printer.isConnected();
    } on PrinterException catch (e) {
      _error = e.message;
      _printers = [];
    } catch (e) {
      _error = e.toString();
      _printers = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPrinter(BluetoothInfo info) async {
    await store.setPrinter(info.name, info.macAdress);
    setState(() {});
    try {
      await printer.disconnect();
      await printer.connect(info.macAdress);
      _connected = await printer.isConnected();
      _toast('Connected to ${info.name}');
    } on PrinterException catch (e) {
      _toast(e.message, error: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _testPrint() async {
    try {
      await printer.testPrint();
      _toast('Test sent to printer');
    } on NoPrinterSelected {
      _toast('Select a printer first', error: true);
    } on BluetoothOff {
      _toast('Turn on Bluetooth first', error: true);
    } on PrinterException catch (e) {
      _toast(e.message, error: true);
    }
    if (mounted) {
      _connected = await printer.isConnected();
      setState(() {});
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer settings'),
        actions: [
          IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Web URL ----
            const _SectionTitle('UpeoRetail URL'),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://upeoretail.com',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await store.setWebUrl(_urlCtrl.text);
                  // Returning to the web view reloads the saved URL automatically.
                  if (mounted) nav.pop();
                },
                child: const Text('Save & open'),
              ),
            ),

            const SizedBox(height: 16),
            // ---- Paper size ----
            const _SectionTitle('Paper width'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '58', label: Text('58 mm')),
                ButtonSegment(value: '80', label: Text('80 mm')),
              ],
              selected: {store.paperCode},
              onSelectionChanged: (s) async {
                await store.setPaper(s.first);
                setState(() {});
              },
            ),

            const SizedBox(height: 16),
            // ---- Status ----
            const _SectionTitle('Status'),
            _StatusRow(
              icon: _bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
              label: 'Bluetooth',
              value: _bluetoothOn ? 'On' : 'Off',
              ok: _bluetoothOn,
            ),
            _StatusRow(
              icon: Icons.print,
              label: 'Default printer',
              value: store.printerName ?? 'Not set',
              ok: store.hasPrinter,
            ),
            _StatusRow(
              icon: Icons.link,
              label: 'Connection',
              value: _connected ? 'Connected' : 'Not connected',
              ok: _connected,
            ),

            const SizedBox(height: 16),
            // ---- Paired printers ----
            const _SectionTitle('Paired Bluetooth printers'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                ),
              )
            else if (_printers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                      'No paired printers found. Pair your printer (e.g. P58E) in '
                      'Android Bluetooth settings, then pull to refresh.'),
                ),
              )
            else
              ..._printers.map((p) {
                final selected = p.macAdress == store.printerMac;
                return Card(
                  child: ListTile(
                    onTap: () => _selectPrinter(p),
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? Colors.green : Colors.grey,
                    ),
                    title: Text(p.name.isEmpty ? '(unnamed)' : p.name),
                    subtitle: Text(p.macAdress),
                    trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  ),
                );
              }),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _testPrint,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Test print'),
            ),
            if (store.lastStatus != null) ...[
              const SizedBox(height: 12),
              Text('Last: ${store.lastStatus}',
                  style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
      );
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  const _StatusRow({required this.icon, required this.label, required this.value, required this.ok});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ok ? Colors.green : Colors.grey),
            const SizedBox(width: 10),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}
