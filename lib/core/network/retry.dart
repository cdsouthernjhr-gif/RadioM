import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Runs [action] with exponential backoff for transient network errors.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 800),
  bool Function(Object error)? retryIf,
}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (e) {
      final shouldRetry = (retryIf ?? isTransientNetworkError)(e);
      if (!shouldRetry || attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}

bool isTransientNetworkError(Object e) =>
    e is SocketException ||
    e is TimeoutException ||
    e is http.ClientException ||
    e is HttpException ||
    (e is HttpStatusException && e.statusCode >= 500);

class HttpStatusException implements Exception {
  HttpStatusException(this.statusCode, this.url);
  final int statusCode;
  final String url;
  @override
  String toString() => 'HTTP $statusCode ($url)';
}
