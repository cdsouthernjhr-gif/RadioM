import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/core/utils/url_validator.dart';

void main() {
  test('accepts http and https only', () {
    expect(UrlValidator.isValidHttpUrl('https://a.example/stream.mp3'), isTrue);
    expect(UrlValidator.isValidHttpUrl('http://1.2.3.4:8000/;'), isTrue);
    expect(UrlValidator.isValidHttpUrl('ftp://a/b'), isFalse);
    expect(UrlValidator.isValidHttpUrl('javascript:alert(1)'), isFalse);
    expect(UrlValidator.isValidHttpUrl('file:///etc/passwd'), isFalse);
    expect(UrlValidator.isValidHttpUrl(''), isFalse);
    expect(UrlValidator.isValidHttpUrl(null), isFalse);
    expect(UrlValidator.isValidHttpUrl('https://'), isFalse);
  });
  test('rejects embedded credentials and whitespace', () {
    expect(UrlValidator.isValidHttpUrl('https://user:pass@a.example/x'), isFalse);
    expect(UrlValidator.isValidHttpUrl('https://a.example/x y'), isFalse);
  });
  test('isHttps', () {
    expect(UrlValidator.isHttps('https://a.example'), isTrue);
    expect(UrlValidator.isHttps('http://a.example'), isFalse);
  });
}
