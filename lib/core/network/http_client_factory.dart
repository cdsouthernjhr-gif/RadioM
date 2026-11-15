import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Builds HTTP clients with full certificate validation.
///
/// Android 6.0 (API 23) ships without the ISRG Root X1/X2 certificates used
/// by Let's Encrypt. Instead of disabling validation, we *add* these two
/// official root certificates (bundled in assets/certs) to the trust store
/// on top of the system roots. Validation stays fully enabled.
class HttpClientFactory {
  HttpClientFactory._();

  static SecurityContext? _context;

  static Future<void> init() async {
    if (_context != null) return;
    final ctx = SecurityContext(withTrustedRoots: true);
    for (final asset in const ['assets/certs/isrg_root_x1.pem', 'assets/certs/isrg_root_x2.pem']) {
      try {
        final data = await rootBundle.load(asset);
        ctx.setTrustedCertificatesBytes(data.buffer.asUint8List());
      } catch (_) {
        // Already trusted by the OS (newer Android) or asset missing: ignore.
      }
    }
    _context = ctx;
    // Every HttpClient created without an explicit context (plugins included)
    // gets the same trust store. Validation stays on.
    HttpOverrides.global = _TrustOverrides(ctx);
  }

  static http.Client create({Duration connectTimeout = const Duration(seconds: 15)}) {
    final io = HttpClient(context: _context)
      ..connectionTimeout = connectTimeout
      ..idleTimeout = const Duration(seconds: 15);
    // NOTE: badCertificateCallback is intentionally NOT set. TLS validation is never disabled.
    return IOClient(io);
  }
}

class _TrustOverrides extends HttpOverrides {
  _TrustOverrides(this._ctx);
  final SecurityContext _ctx;

  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context ?? _ctx);
}
