/// Comparison helpers for database `version` values.
///
/// Versions are normally integers, but dotted strings such as "2026.11.15"
/// are also supported for robustness.
class VersionUtils {
  VersionUtils._();

  /// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
  static int compare(Object? a, Object? b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static bool isNewer(Object? remote, Object? local) => compare(remote, local) > 0;

  static List<int> _parts(Object? v) {
    if (v == null) return const [0];
    if (v is int) return [v];
    if (v is num) return [v.toInt()];
    return v
        .toString()
        .trim()
        .split(RegExp(r'[.\-+]'))
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
