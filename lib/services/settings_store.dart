import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Thin, typed wrapper around SharedPreferences for the app's persisted state:
/// default printer (name + MAC), paper size, web URL and last status.
class SettingsStore {
  static const _kName = 'printer_name';
  static const _kMac = 'printer_mac';
  static const _kPaper = 'paper_size'; // '58' or '80'
  static const _kStatus = 'last_status';
  static const _kUrl = 'web_url';

  final SharedPreferences _p;
  SettingsStore(this._p);

  static Future<SettingsStore> create() async =>
      SettingsStore(await SharedPreferences.getInstance());

  String? get printerName => _p.getString(_kName);
  String? get printerMac => _p.getString(_kMac);
  bool get hasPrinter => (printerMac ?? '').isNotEmpty;

  String get paperCode => _p.getString(_kPaper) ?? '58';
  PaperSize get paperSize => paperCode == '80' ? PaperSize.mm80 : PaperSize.mm58;
  String get paperLabel => paperCode == '80' ? '80mm' : '58mm';

  String get webUrl => _p.getString(_kUrl) ?? AppConfig.defaultUrl;
  String? get lastStatus => _p.getString(_kStatus);

  Future<void> setPrinter(String name, String mac) async {
    await _p.setString(_kName, name);
    await _p.setString(_kMac, mac);
  }

  Future<void> clearPrinter() async {
    await _p.remove(_kName);
    await _p.remove(_kMac);
  }

  Future<void> setPaper(String code) => _p.setString(_kPaper, code == '80' ? '80' : '58');
  Future<void> setWebUrl(String url) => _p.setString(_kUrl, url.trim());
  Future<void> setLastStatus(String s) => _p.setString(_kStatus, s);
}
