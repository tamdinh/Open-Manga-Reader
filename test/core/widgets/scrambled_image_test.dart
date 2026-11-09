import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/utils/page_scramble.dart';
import 'package:my_manga_reader/core/widgets/scrambled_image.dart';

void main() {
  testWidgets('ScrambledImage shows the page put back, at its own size, and reports its aspect ratio', (tester) async {
    const w = 120, h = 80, tiles = 4, seed = 99;
    final g = PageScrambler.geometry(w, h, tiles)!;
    final perm = PageScrambler.permutation(seed, g.count);

    // left half red, right half blue: easy to see where the tiles went
    Uint8List rgba(bool Function(int x, int y) isRed) {
      final data = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final red = isRed(x, y);
          data[i] = red ? 255 : 0;
          data[i + 2] = red ? 0 : 255;
          data[i + 3] = 255;
        }
      }
      return data;
    }

    final original = rgba((x, y) => x < w ~/ 2);
    final sent = Uint8List.fromList(original);
    for (var p = 0; p < g.count; p++) {
      final o = perm[p];
      for (var row = 0; row < g.size; row++) {
        final from = (((o ~/ g.cols) * g.size + row) * w + (o % g.cols) * g.size) * 4;
        final to = (((p ~/ g.cols) * g.size + row) * w + (p % g.cols) * g.size) * 4;
        sent.setRange(to, to + g.size * 4, original.sublist(from, from + g.size * 4));
      }
    }
    expect(sent, isNot(equals(original)));

    late Uint8List png;
    await tester.runAsync(() async {
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(sent, w, h, ui.PixelFormat.rgba8888, c.complete);
      final image = await c.future;
      png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
    });

    double? ratio;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ScrambledImage(
          provider: MemoryImage(png),
          scramble: const PageScramble(seed: seed, tiles: tiles),
          width: 240,
          onAspectRatio: (r) => ratio = r,
        ),
      ),
    ));

    // decoding and composing happen off the test clock: give them real time, until the picture is there
    for (var i = 0; i < 40 && find.byType(RawImage).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.image!.width, w);
    expect(raw.image!.height, h);
    expect(ratio, closeTo(h / w, 1e-9));
    // laid out like Image(fit: fitWidth, width: 240): the height follows the picture
    expect(tester.getSize(find.byType(RawImage)), const Size(240, 160));

    late Uint8List shown;
    await tester.runAsync(() async {
      shown = (await raw.image!.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    });
    expect(shown, original);
  });

  testWidgets('a picture that cannot be loaded shows the error widget', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ScrambledImage(
        provider: MemoryImage(Uint8List.fromList([1, 2, 3])),
        scramble: const PageScramble(seed: 1, tiles: 6),
        errorBuilder: (context, error) => const Text('broken'),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('broken'), findsOneWidget);
  });
}
