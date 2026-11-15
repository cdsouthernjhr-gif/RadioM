/// Application-wide constants. No secrets or tokens are stored here.
class AppConstants {
  AppConstants._();

  static const String appName = 'Malaysia Radio Player';
  static const String appVersion = '1.0.0';
  static const int appBuild = 1;

  /// Highest database schema this build understands.
  static const int supportedSchemaVersion = 1;

  /// Remote database hosted in GitHub (raw content, HTTPS).
  static const String remoteDatabaseUrl =
      'https://raw.githubusercontent.com/cdsouthernjhr-gif/RadioM/main/data/malaysia_radio.json';

  /// Small manifest used to check whether a new database exists before
  /// downloading the full file.
  static const String remoteVersionUrl =
      'https://raw.githubusercontent.com/cdsouthernjhr-gif/RadioM/main/data/version.json';

  static const String bundledDatabaseAsset = 'assets/data/malaysia_radio.json';
  static const String cachedDatabaseFile = 'malaysia_radio.json';

  static const Duration httpTimeout = Duration(seconds: 15);
  static const int httpMaxRetries = 3;

  /// Automatic refresh will not run more often than this.
  static const Duration autoRefreshInterval = Duration(hours: 12);

  /// Max size accepted for the remote JSON (protects low-memory TV boxes).
  static const int maxDatabaseBytes = 2 * 1024 * 1024;

  static const String userAgent = 'MalaysiaRadioPlayer/$appVersion (Android)';

  static const int recentLimit = 12;
}
