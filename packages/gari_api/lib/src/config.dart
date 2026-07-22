import 'package:flutter/foundation.dart' show kIsWeb;

class GariConfig {
  /// Override with --dart-define=GARI_API_URL=http://...
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('GARI_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Flutter web / desktop → localhost. Android emulator → 10.0.2.2.
    if (kIsWeb) return 'http://localhost:4000';
    return 'http://10.0.2.2:4000';
  }

  static String get socketUrl {
    const fromEnv = String.fromEnvironment('GARI_SOCKET_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:4000';
    return 'http://10.0.2.2:4000';
  }

  /// Resolve `/uploads/...` to a full URL the web app can load.
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }
}
