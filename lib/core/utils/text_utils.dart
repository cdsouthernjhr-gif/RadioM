class TextUtils {
  TextUtils._();

  static const Map<String, String> languageNames = {
    'ms': 'Bahasa Melayu',
    'en': 'English',
    'zh': 'Cina',
    'ta': 'Tamil',
    'iban': 'Iban',
    'bidayuh': 'Bidayuh',
    'kadazandusun': 'Kadazandusun',
    'orang-asli': 'Orang Asli',
  };

  static String languageName(String code) => languageNames[code] ?? code;

  static const Map<String, String> categoryNames = {
    'rtm': 'RTM',
    'commercial': 'Komersial',
    'internet': 'Radio Internet',
  };

  static String categoryName(String code) => categoryNames[code] ?? code;

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Lower-case, accent-insensitive-ish normalisation for search.
  static String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9一-鿿஀-௿]+'), '');

  static String formatDate(DateTime? d) {
    if (d == null) return '-';
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}
