import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'http_client_factory.dart';

/// Disk cache for station logos. Uses the app's HTTP client so logos get the
/// same TLS trust store as the database download (system roots + ISRG roots
/// for Android 6.0); certificate validation is never disabled.
class LogoCache {
  LogoCache._();

  static CacheManager? _instance;

  static CacheManager get instance => _instance ??= CacheManager(Config(
        'station_logos',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 300,
        fileService: HttpFileService(httpClient: HttpClientFactory.create()),
      ));

  static Future<void> clear() => instance.emptyCache();
}
