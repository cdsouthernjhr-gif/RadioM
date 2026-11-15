import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/core/utils/version_utils.dart';

void main() {
  group('Version comparison', () {
    test('integers', () {
      expect(VersionUtils.isNewer(2, 1), isTrue);
      expect(VersionUtils.isNewer(1, 1), isFalse);
      expect(VersionUtils.isNewer(1, 2), isFalse);
    });
    test('dotted strings', () {
      expect(VersionUtils.compare('2026.11.15', '2026.11.9'), greaterThan(0));
      expect(VersionUtils.compare('1.0', '1.0.0'), 0);
      expect(VersionUtils.compare('1.2.0', '1.10.0'), lessThan(0));
    });
    test('mixed and null', () {
      expect(VersionUtils.compare(3, '3'), 0);
      expect(VersionUtils.isNewer(1, null), isTrue);
      expect(VersionUtils.compare(null, null), 0);
    });
  });
}
