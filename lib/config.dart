/// App-wide configuration and constants.
class AppConfig {
  AppConfig._();

  static const String appName = 'UpeoRetail Print';

  /// Default web app URL — the live selling app. Overridable at runtime in
  /// Printer Settings.
  static const String defaultUrl = 'https://demo.upeoretail.com';

  /// JavaScript channel name the Next.js app posts print messages to.
  static const String jsChannel = 'UpeoRetailPrinter';

  /// Message type the bridge accepts. Everything else is ignored.
  static const String printType = 'PRINT_RECEIPT';

  /// Only print messages coming from these hosts (or their subdomains) are
  /// honoured. Tighten/extend this list to match your deployment.
  static const List<String> allowedHosts = <String>[
    'upeoretail.com',
    'demo.upeoretail.com',
  ];

  /// Brand colour (UpeoRetail orange).
  static const int brandColor = 0xFFFF6B1A;

  /// True if [host] is an allowed origin (exact match or a subdomain).
  static bool isAllowedHost(String? host) {
    if (host == null || host.isEmpty) return false;
    final h = host.toLowerCase();
    for (final a in allowedHosts) {
      if (h == a || h.endsWith('.$a')) return true;
    }
    return false;
  }
}
