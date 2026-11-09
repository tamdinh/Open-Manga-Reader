import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/utils/url_utils.dart';

void main() {
  group('UrlUtils Tests', () {
    test('isLocalFilePath identifies network vs local paths accurately', () {
      expect(UrlUtils.isLocalFilePath('http://example.com/image.jpg'), isFalse);
      expect(UrlUtils.isLocalFilePath('https://example.com/image.jpg'), isFalse);
      expect(UrlUtils.isLocalFilePath('//cdn.example.com/image.jpg'), isFalse);
      expect(UrlUtils.isLocalFilePath('   https://example.com/image.jpg '), isFalse);

      expect(UrlUtils.isLocalFilePath(r'D:\Documents\downloads\ch1\001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('D:/Documents/downloads/ch1/001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('D:%5CDocuments/downloads/ch1/001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('/data/user/0/cache/image.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('file:///D:/Documents/ch1/001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath(''), isFalse);
    });

    test('normalizeLocalFilePath unescapes %5C and %20 on Windows paths', () {
      const encodedWindowsPath =
          'D:%5CDocuments/downloads/01a02058-35ce-7471-90ea-63d960ce9fc6/01a02058-35d5-75bc-9637-3369bd2153f5/006.webp';

      final normalized = UrlUtils.normalizeLocalFilePath(encodedWindowsPath);

      if (Platform.isWindows) {
        expect(
          normalized,
          r'D:\Documents\downloads\01a02058-35ce-7471-90ea-63d960ce9fc6\01a02058-35d5-75bc-9637-3369bd2153f5\006.webp',
        );
      } else {
        expect(normalized, contains(r'D:\Documents/downloads'));
      }
    });

    test('sanitizeImageUrl does NOT URL-encode backslashes for local files', () {
      const windowsLocalPath = r'D:\Documents\downloads\ch1\001.webp';
      final sanitized = UrlUtils.sanitizeImageUrl(windowsLocalPath);

      expect(sanitized.contains('%5C'), isFalse);
      expect(sanitized.contains('%5c'), isFalse);

      // Network URLs should still be encoded
      const networkUrl = 'https://example.com/folder name/image.jpg';
      final sanitizedNetwork = UrlUtils.sanitizeImageUrl(networkUrl);
      expect(sanitizedNetwork, 'https://example.com/folder%20name/image.jpg');
    });

    group('signed page links', () {
      final future = DateTime.now().toUtc().add(const Duration(hours: 2));
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      String signed(DateTime e, [String path = 'https://api.example.com/images/T/vi/1/1.avif']) =>
          '$path?e=${e.millisecondsSinceEpoch ~/ 1000}&s=abcdefghijklmnopqrstuv';

      test('cacheKey drops e and s but keeps other parameters', () {
        const base = 'https://api.example.com/images/T/vi/1/1.avif';
        expect(UrlUtils.cacheKey('$base?e=1794202261&s=abc'), base);
        expect(UrlUtils.cacheKey('$base?e=1&s=abc&fmt=jpg&w=1024'), '$base?fmt=jpg&w=1024');
        expect(UrlUtils.cacheKey('$base?still=1&w=240'), '$base?still=1&w=240');
        expect(UrlUtils.cacheKey(base), base);
      });

      test('two renewals of the same page share one cache key', () {
        expect(UrlUtils.cacheKey(signed(future)), UrlUtils.cacheKey(signed(future.add(const Duration(hours: 1)))));
      });

      test('isSignedUrl and expiry', () {
        expect(UrlUtils.isSignedUrl(signed(future)), isTrue);
        expect(UrlUtils.isSignedUrl('https://api.example.com/images/T/thumbnail.webp?still=1'), isFalse);
        expect(UrlUtils.isSignedUrl('https://api.example.com/images/T/1.avif?e=abc'), isFalse);
        expect(UrlUtils.isSignedUrlExpired(signed(future)), isFalse);
        expect(UrlUtils.isSignedUrlExpired(signed(past)), isTrue);
        // inside the 1 minute slack counts as expired, so a link is renewed before it fails
        expect(UrlUtils.isSignedUrlExpired(signed(DateTime.now().toUtc().add(const Duration(seconds: 30)))), isTrue);
        expect(UrlUtils.isSignedUrlExpired('https://api.example.com/images/T/thumbnail.webp'), isFalse);
      });

      test('a signed URL survives sanitizeImageUrl with its query intact', () {
        final url = signed(future, 'https://api.example.com/images/Vết Cắn/vi/1/1.avif');
        final sanitized = UrlUtils.sanitizeImageUrl(url);
        expect(sanitized, contains('?e='));
        expect(sanitized, contains('&s=abcdefghijklmnopqrstuv'));
        expect(sanitized, isNot(contains(' ')));
        expect(UrlUtils.isSignedUrl(sanitized), isTrue);
      });
    });
  });
}
