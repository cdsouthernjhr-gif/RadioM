/// "Now playing" text carried inside an internet radio stream — the stream
/// equivalent of FM RDS RadioText (RT) / Programme Service name (PS).
///
/// Sources:
///  * ICY metadata (Icecast/Shoutcast `StreamTitle='Artist - Title';`)
///  * ICY headers (`icy-name`, `icy-genre`) sent once when the stream opens
///
/// The text comes from the broadcaster's server, so it is treated as
/// untrusted: control characters are removed, whitespace collapsed, length
/// capped, and placeholder values dropped. It is only ever displayed as plain
/// text (never parsed as a URL or markup).
class NowPlaying {
  const NowPlaying({required this.text, this.artist, this.title});

  /// Cleaned full text, e.g. "Siti Nurhaliza - Cindai".
  final String text;

  /// Set when [text] has the conventional "Artist - Title" form.
  final String? artist;
  final String? title;

  /// Title-first line for notification / lock screen (MediaItem.title).
  String get headline => title ?? text;

  @override
  bool operator ==(Object other) => other is NowPlaying && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'NowPlaying($text)';

  static const maxLength = 160;

  // Values servers send when there is no real song information.
  static final _placeholders = RegExp(
    r'^(?:-+|unknown|untitled|n/?a|null|none|live|on ?air|stream|radio|'
    r'advert(?:isement)?|iklan|commercial|ads?|station id|jingle|\s*)$',
    caseSensitive: false,
  );

  static final _control = RegExp('[\\u0000-\\u001F\\u007F-\\u009F\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069]');

  /// Cleans one raw value. Returns null when nothing meaningful remains.
  static String? clean(String? raw) {
    if (raw == null) return null;
    var s = raw.replaceAll(_control, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    // Some servers wrap the whole value in quotes.
    if (s.length >= 2 && (s.startsWith("'") && s.endsWith("'") || s.startsWith('"') && s.endsWith('"'))) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty || _placeholders.hasMatch(s)) return null;
    // Bare URLs (station websites pushed as titles) carry no song information.
    if (RegExp(r'^(?:https?://|www\.)\S+$', caseSensitive: false).hasMatch(s)) return null;
    if (s.length > maxLength) s = '${s.substring(0, maxLength - 1).trimRight()}…';
    return s;
  }

  /// Parses an ICY `StreamTitle` value. [stationName] lets us drop titles that
  /// only repeat the station name (that is PS-like data, not RadioText).
  static NowPlaying? parse(String? raw, {String? stationName}) {
    final text = clean(raw);
    if (text == null) return null;
    if (stationName != null && _same(text, stationName)) return null;
    final m = RegExp(r'^(.+?)\s+[-–—]\s+(.+)$').firstMatch(text);
    if (m != null) {
      final artist = m.group(1)!.trim();
      final title = m.group(2)!.trim();
      final artistOk = clean(artist) != null;
      final titleOk = clean(title) != null;
      if (artistOk && titleOk) return NowPlaying(text: text, artist: artist, title: title);
      if (titleOk) return NowPlaying(text: title, title: title);
      if (artistOk) return NowPlaying(text: artist);
      return null;
    }
    return NowPlaying(text: text);
  }

  static bool _same(String a, String b) {
    String n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return n(a) == n(b);
  }
}
