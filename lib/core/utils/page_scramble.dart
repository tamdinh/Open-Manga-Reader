import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// How a scrambled chapter page is put back together. The chapter response carries a [seed] (made from a server secret,
/// so it cannot be derived from the image link) and the number of [tiles] per row for every page the server scrambled.
class PageScramble {
  final int seed;
  final int tiles;

  const PageScramble({required this.seed, required this.tiles});

  @override
  bool operator ==(Object other) =>
      other is PageScramble && other.seed == seed && other.tiles == tiles;

  @override
  int get hashCode => Object.hash(seed, tiles);

  @override
  String toString() => 'PageScramble(seed: $seed, tiles: $tiles)';
}

/// The grid a page is cut into.
class ScrambleGeometry {
  final int cols;
  final int rows;
  final int size;

  const ScrambleGeometry(this.cols, this.rows, this.size);

  int get count => cols * rows;

  @override
  bool operator ==(Object other) =>
      other is ScrambleGeometry &&
      other.cols == cols &&
      other.rows == rows &&
      other.size == size;

  @override
  int get hashCode => Object.hash(cols, rows, size);

  @override
  String toString() => 'ScrambleGeometry($cols x $rows, $size px)';
}

/// Tile scrambling of chapter pages, the reader's half. The server and every client must compute exactly the same
/// geometry and permutation: integer arithmetic on 32 bits, pinned by the same test vectors as the C# and JavaScript
/// implementations (test/core/utils/page_scramble_test.dart). Nothing here uses `<<`, `*` on values that can pass 2^53
/// or the 64-bit `int`, so it also gives the same answer when Flutter runs on the web (where `int` is a double).
class PageScrambler {
  PageScrambler._();

  /// More pixels than this and the server leaves the page alone (a browser canvas cannot hold more).
  static const int maxPixels = 12000000;
  static const int minTiles = 3;
  static const int maxTilesAcross = 16;
  static const int maxTileCount = 1500;
  static const int minTileSize = 8;

  /// The grid for a page of this size, or null when the page is not scrambled (too big, or too small to tile).
  static ScrambleGeometry? geometry(int width, int height, int tilesAcross) {
    if (width <= 0 || height <= 0 || width * height > maxPixels) return null;

    final across = tilesAcross.clamp(minTiles, maxTilesAcross);
    var size = width ~/ across;
    if (size < minTileSize) size = minTileSize;
    while ((width ~/ size) * (height ~/ size) > maxTileCount) {
      size += minTileSize;
    }

    final cols = width ~/ size;
    final rows = height ~/ size;
    return cols * rows >= 2 ? ScrambleGeometry(cols, rows, size) : null;
  }

  static const int _mask = 0xFFFFFFFF;
  static const int _two32 = 0x100000000;

  /// 32-bit multiply (Math.imul) from 16-bit halves: exact on the VM and on the web.
  static int _imul(int a, int b) {
    a &= _mask;
    b &= _mask;
    final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
    final high = ((ah * bl + al * bh) % 0x10000) * 0x10000;
    return (al * bl + high) % _two32;
  }

  /// mulberry32, raw 32-bit steps.
  static int Function() _rng(int seed) {
    var a = seed & _mask;
    return () {
      a = (a + 0x6D2B79F5) & _mask;
      var t = a;
      t = _imul(t ^ (t >> 15), t | 1);
      t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) % _two32)) & _mask;
      return (t ^ (t >> 14)) & _mask;
    };
  }

  /// The scrambled page holds original tile `perm[p]` at position `p`.
  static List<int> permutation(int seed, int count) {
    final perm = List<int>.generate(count, (i) => i);
    final next = _rng(seed);
    for (var i = count - 1; i > 0; i--) {
      final j = next() % (i + 1);
      final tmp = perm[i];
      perm[i] = perm[j];
      perm[j] = tmp;
    }
    return perm;
  }

  /// The page put back in order, at its own size. [scrambled] stays the caller's to dispose. When the page is not one
  /// the server scrambled (its size says so: the server applies the same rule to the same size) a copy is returned.
  static Future<ui.Image> compose(ui.Image scrambled, PageScramble scramble) async {
    final g = geometry(scrambled.width, scrambled.height, scramble.tiles);
    if (g == null) return scrambled.clone();

    final perm = permutation(scramble.seed, g.count);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    // The whole picture first: the strips right of and below the grid are not scrambled and stay as they are.
    canvas.drawImage(scrambled, Offset.zero, paint);
    final s = g.size.toDouble();
    for (var p = 0; p < perm.length; p++) {
      final o = perm[p];
      canvas.drawImageRect(
        scrambled,
        Rect.fromLTWH((p % g.cols) * s, (p ~/ g.cols) * s, s, s),
        Rect.fromLTWH((o % g.cols) * s, (o ~/ g.cols) * s, s, s),
        paint,
      );
    }

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(scrambled.width, scrambled.height);
    } finally {
      picture.dispose();
    }
  }

  /// For saving a page to the device: the picture as PNG with the tiles back in place. Null when [bytes] cannot be
  /// decoded or the page is not one the server scrambled (the caller keeps the bytes as they are).
  static Future<Uint8List?> unscrambleToPng(Uint8List bytes, PageScramble scramble) async {
    ui.Codec? codec;
    ui.Image? decoded;
    ui.Image? composed;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      if (geometry(decoded.width, decoded.height, scramble.tiles) == null) return null;

      composed = await compose(decoded, scramble);
      final data = await composed.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    } finally {
      composed?.dispose();
      decoded?.dispose();
      codec?.dispose();
    }
  }
}
