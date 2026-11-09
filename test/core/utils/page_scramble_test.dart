import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/models/chapter_page.dart';
import 'package:my_manga_reader/core/utils/page_scramble.dart';

// The vectors are the same as in OpenMangaAPI/tests/UnitTests/MangaScrapper/ImageScrambleTests.cs and in
// OpenMangaWeb/test/scramble.test.mjs: all three must agree, or pages come out jumbled.
void main() {
  group('permutation and geometry match the server', () {
    test('permutation vectors', () {
      expect(PageScrambler.permutation(12345, 10), [3, 1, 5, 8, 7, 0, 4, 2, 6, 9]);
      expect(PageScrambler.permutation(0xDEADBEEF, 16),
          [1, 4, 13, 6, 12, 5, 3, 9, 7, 11, 15, 14, 0, 8, 2, 10]);
      expect(PageScrambler.permutation(0, 6), [1, 4, 3, 0, 5, 2]);
    });

    test('a permutation of 500 is a permutation', () {
      final p = PageScrambler.permutation(987654321, 500)..sort();
      expect(p, List<int>.generate(500, (i) => i));
    });

    test('geometry vectors', () {
      expect(PageScrambler.geometry(800, 1200, 6), const ScrambleGeometry(6, 9, 133));
      expect(PageScrambler.geometry(100, 80, 6), const ScrambleGeometry(6, 5, 16));
      expect(PageScrambler.geometry(1000, 40, 6), isNull); // too short to tile
      expect(PageScrambler.geometry(4000, 4000, 6), isNull); // more pixels than a canvas holds
      expect(PageScrambler.geometry(0, 100, 6), isNull);

      final tall = PageScrambler.geometry(800, 14000, 6)!;
      expect(tall.count, lessThanOrEqualTo(1500));
      expect(tall.size, greaterThanOrEqualTo(133));
      expect(PageScrambler.geometry(800, 1200, 100)!.cols, 800 ~/ (800 ~/ 16)); // clamped to 16 across
    });
  });

  group('putting a page back together', () {
    const w = 130, h = 97, tiles = 4, seed = 4242;

    // original pixel (x, y): distinct enough that a misplaced tile shows
    Uint8List original() {
      final data = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          data[i] = (x * 7 + y) & 0xFF;
          data[i + 1] = (y * 5 + x ~/ 3) & 0xFF;
          data[i + 2] = (x ^ y) & 0xFF;
          data[i + 3] = 255;
        }
      }
      return data;
    }

    /// What the server does: position p of the sent image holds original tile perm[p]; the strips stay.
    Uint8List scramble(Uint8List src) {
      final g = PageScrambler.geometry(w, h, tiles)!;
      final perm = PageScrambler.permutation(seed, g.count);
      final out = Uint8List.fromList(src);
      for (var p = 0; p < g.count; p++) {
        final o = perm[p];
        for (var row = 0; row < g.size; row++) {
          final from = (((o ~/ g.cols) * g.size + row) * w + (o % g.cols) * g.size) * 4;
          final to = (((p ~/ g.cols) * g.size + row) * w + (p % g.cols) * g.size) * 4;
          out.setRange(to, to + g.size * 4, src.sublist(from, from + g.size * 4));
        }
      }
      return out;
    }

    Future<ui.Image> image(Uint8List rgba) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
      return completer.future;
    }

    Future<Uint8List> pixels(ui.Image img) async =>
        (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

    testWidgets('compose restores the picture exactly, strips included', (tester) async {
      await tester.runAsync(() async {
        final src = original();
        final sent = scramble(src);
        expect(sent, isNot(equals(src))); // the test would prove nothing otherwise

        final scrambled = await image(sent);
        final restored = await PageScrambler.compose(scrambled, const PageScramble(seed: seed, tiles: tiles));

        expect(restored.width, w);
        expect(restored.height, h);
        expect(await pixels(restored), src);
        restored.dispose();
        scrambled.dispose();
      });
    });

    testWidgets('a page the server would not scramble comes back unchanged', (tester) async {
      await tester.runAsync(() async {
        final data = Uint8List(20 * 6 * 4)..fillRange(0, 20 * 6 * 4, 9);
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(data, 20, 6, ui.PixelFormat.rgba8888, completer.complete);
        final small = await completer.future;

        final same = await PageScrambler.compose(small, const PageScramble(seed: 1, tiles: 6));
        expect(await pixels(same), data);
        same.dispose();
        small.dispose();
      });
    });

    testWidgets('unscrambleToPng gives a PNG of the restored picture (what an offline download stores)', (tester) async {
      await tester.runAsync(() async {
        final src = original();
        final scrambled = await image(scramble(src));
        final png = (await scrambled.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        scrambled.dispose();

        final restoredPng = await PageScrambler.unscrambleToPng(png, const PageScramble(seed: seed, tiles: tiles));
        expect(restoredPng, isNotNull);

        final codec = await ui.instantiateImageCodec(restoredPng!);
        final frame = await codec.getNextFrame();
        expect(await pixels(frame.image), src);
        frame.image.dispose();
        codec.dispose();

        // bytes that are not an image, or a page that is not scrambled: null, the caller keeps the original
        expect(await PageScrambler.unscrambleToPng(Uint8List.fromList([1, 2, 3]), const PageScramble(seed: 1, tiles: 6)), isNull);
      });
    });
  });

  group('ChapterPage carries the scramble', () {
    test('parses seed and tiles, and keeps them through copyWith and toMap', () {
      final page = ChapterPage.fromMap({
        'url': 'T/vi/1/1.avif?e=1&s=2&v=abcd1234',
        'width': 800,
        'height': 1200,
        'scrambleSeed': 3735928559, // above 2^31: must stay a positive number
        'scrambleTiles': 6,
      });

      expect(page.scramble, const PageScramble(seed: 3735928559, tiles: 6));
      final moved = page.copyWith(url: 'https://api.example/images/T/vi/1/1.avif?e=1&s=2&v=abcd1234');
      expect(moved.scramble, page.scramble);
      expect(ChapterPage.fromMap(moved.toMap()), moved);
    });

    test('a page without the fields is not scrambled', () {
      expect(ChapterPage.fromMap({'url': 'T/1.avif'}).scramble, isNull);
      expect(ChapterPage.fromMap({'url': 'T/1.avif', 'scrambleSeed': 5}).scramble, isNull);
      expect(ChapterPage.fromMap({'url': 'T/1.avif', 'scrambleSeed': 5, 'scrambleTiles': 0}).scramble, isNull);
    });
  });
}
