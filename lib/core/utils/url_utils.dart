import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class UrlUtils {
  /// Determines whether the given string represents a local file path.
  static bool isLocalFilePath(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//')) {
      return false;
    }
    return true;
  }

  /// Normalizes a local file path (handles file:// URIs, URL-encoded %5C or %20,
  /// and Windows path separators).
  static String normalizeLocalFilePath(String path) {
    String clean = path.trim();
    if (clean.isEmpty) return clean;

    if (clean.startsWith('file://')) {
      try {
        clean = Uri.parse(clean).toFilePath(windows: !kIsWeb && Platform.isWindows);
      } catch (_) {
        clean = clean.replaceFirst('file://', '');
      }
    }

    // Unescape URL-encoded backslashes and spaces
    clean = clean.replaceAll('%5C', r'\').replaceAll('%5c', r'\');
    clean = clean.replaceAll('%20', ' ');

    if (clean.contains('%')) {
      try {
        clean = Uri.decodeComponent(clean);
      } catch (_) {}
    }

    if (!kIsWeb && Platform.isWindows) {
      // If it starts with /C: or /D: from URI parsing, strip leading slash
      if (RegExp(r'^\/[a-zA-Z]:').hasMatch(clean)) {
        clean = clean.substring(1);
      }
      clean = clean.replaceAll('/', r'\');
    }

    return clean;
  }

  /// Chapter pages come with a signed link (`...?e=<expiry unix seconds>&s=<signature>`, valid ~2-3 hours).
  static bool isSignedUrl(String url) => signedUrlExpiry(url) != null;

  /// Expiry of a signed link, or null when the URL is not signed.
  static DateTime? signedUrlExpiry(String url) {
    final i = url.indexOf('?');
    if (i < 0) return null;
    for (final p in url.substring(i + 1).split('&')) {
      if (p.startsWith('e=')) {
        final seconds = int.tryParse(p.substring(2));
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
        }
      }
    }
    return null;
  }

  static bool isSignedUrlExpired(
    String url, {
    Duration slack = const Duration(minutes: 1),
  }) {
    final expiry = signedUrlExpiry(url);
    return expiry != null && !expiry.isAfter(DateTime.now().toUtc().add(slack));
  }

  /// Key an image is cached under: the URL without the signature (`e`, `s`). The link is renewed every hour, the
  /// picture is the same, so it must keep hitting the cache. Unsigned URLs are returned unchanged.
  static String cacheKey(String url) {
    final i = url.indexOf('?');
    if (i < 0) return url;
    final kept = url
        .substring(i + 1)
        .split('&')
        .where((p) => p.isNotEmpty && !p.startsWith('e=') && !p.startsWith('s='))
        .toList();
    final base = url.substring(0, i);
    return kept.isEmpty ? base : '$base?${kept.join('&')}';
  }

  static String sanitizeImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    // Never URL-encode local file paths
    if (isLocalFilePath(trimmed)) {
      return normalizeLocalFilePath(trimmed);
    }

    try {
      String decoded = trimmed;
      // Unwrap any potential double/triple encoding
      for (int i = 0; i < 3; i++) {
        if (decoded.contains('%20') || decoded.contains('%25')) {
          final next = Uri.decodeFull(decoded);
          if (next == decoded) break;
          decoded = next;
        } else {
          break;
        }
      }
      return Uri.encodeFull(decoded);
    } catch (_) {
      return Uri.encodeFull(trimmed);
    }
  }
}
