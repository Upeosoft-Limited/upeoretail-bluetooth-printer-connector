import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/receipt.dart';
import 'escpos_builder.dart';
import 'settings_store.dart';

/// Typed errors so the UI can react precisely (choose printer / turn on BT /
/// grant permission / printer offline) instead of showing a generic failure.
class PrinterException implements Exception {
  final String message;
  const PrinterException(this.message);
  @override
  String toString() => message;
}

class NoPrinterSelected extends PrinterException {
  const NoPrinterSelected() : super('No default printer selected.');
}

class BluetoothOff extends PrinterException {
  const BluetoothOff() : super('Bluetooth is turned off.');
}

class PermissionDenied extends PrinterException {
  const PermissionDenied() : super('Bluetooth permission was denied.');
}

class PrinterUnavailable extends PrinterException {
  const PrinterUnavailable(super.message);
}

/// Bluetooth Classic (SPP) ESC/POS printing. No BLE, no RawBT, no external app.
class PrinterService {
  final SettingsStore store;
  PrinterService(this.store);

  /// Request the runtime permissions needed across Android versions.
  /// On Android < 12 the bluetooth* permissions resolve automatically; we still
  /// request location which older versions need for Bluetooth.
  Future<void> ensurePermissions() async {
    final statuses = await <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final connect = statuses[Permission.bluetoothConnect];
    // Only hard-fail when the user permanently denied connect on Android 12+.
    if (connect != null && (connect.isPermanentlyDenied || connect.isDenied)) {
      // isDenied is also true on <12 where it's irrelevant; guard with scan.
      final scan = statuses[Permission.bluetoothScan];
      final blockedOn12Plus = connect.isPermanentlyDenied ||
          (connect.isDenied && (scan?.isDenied ?? false) && (scan?.isPermanentlyDenied ?? false));
      if (blockedOn12Plus) throw const PermissionDenied();
    }
  }

  Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  /// Bonded/paired devices. Thermal printers must be paired in Android settings
  /// first; we never need scanning/location for bonded devices on 12+.
  Future<List<BluetoothInfo>> pairedPrinters() async {
    await ensurePermissions();
    if (!await isBluetoothOn()) throw const BluetoothOff();
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> connect(String mac) async {
    if (!await isBluetoothOn()) throw const BluetoothOff();
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!ok) {
      throw const PrinterUnavailable(
          'Could not connect. Make sure the printer is on, charged and in range.');
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {/* ignore */}
  }

  /// Connect to the saved default printer if not already connected.
  /// When [force] is set, drops any stale connection and reconnects — used as a
  /// recovery step when a write fails because the SPP socket silently dropped.
  Future<void> ensureConnectedToDefault({bool force = false}) async {
    await ensurePermissions();
    final mac = store.printerMac;
    if (mac == null || mac.isEmpty) throw const NoPrinterSelected();
    if (!await isBluetoothOn()) throw const BluetoothOff();
    if (force) {
      await disconnect();
    } else if (await isConnected()) {
      return;
    }
    await connect(mac);
  }

  Future<bool> _writeOnce(List<int> bytes) => PrintBluetoothThermal.writeBytes(bytes);

  /// Write bytes, recovering once from a dropped connection. `isConnected()`
  /// can report a stale "connected" after the printer sleeps or goes out of
  /// range, so on the first failure we force a fresh reconnect and retry.
  Future<void> _write(List<int> bytes) async {
    if (await _writeOnce(bytes)) return;
    await ensureConnectedToDefault(force: true);
    if (await _writeOnce(bytes)) return;
    throw const PrinterUnavailable(
        'Could not reach the printer. Make sure it is on, charged and in range.');
  }

  Future<void> printReceipt(Receipt r) async {
    await ensureConnectedToDefault();
    final bytes = await EscPosBuilder.build(r, store.paperSize);
    await _write(bytes);
    await store.setLastStatus(
        'Printed ${r.invoiceNo.isEmpty ? 'receipt' : r.invoiceNo} • ${DateTime.now()}');
  }

  Future<void> testPrint() async {
    await ensureConnectedToDefault();
    final bytes = await EscPosBuilder.buildTest(store.paperSize);
    await _write(bytes);
    await store.setLastStatus('Test print • ${DateTime.now()}');
  }
}
