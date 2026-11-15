/// URL validation helpers. Only http/https are accepted; credentials embedded
/// in URLs are rejected so no secrets end up in the database.
class UrlValidator {
  UrlValidator._();

  static Uri? parseHttpUrl(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 2048) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (trimmed.contains(RegExp(r'\s'))) return null;
    return uri;
  }

  static bool isValidHttpUrl(String? value) => parseHttpUrl(value) != null;

  static bool isHttps(String? value) => parseHttpUrl(value)?.scheme == 'https';
}
