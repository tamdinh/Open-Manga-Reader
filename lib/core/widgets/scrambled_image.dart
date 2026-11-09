import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../utils/page_scramble.dart';

/// Shows a scrambled chapter page the right way round. [provider] gives the picture as the server sent it (tiles in
/// another order); once it has loaded the tiles are put back in a new image of the same size, which is then shown like a
/// normal [Image] would be (so there are no seams, whatever the scale). Nothing is cut or resized on the way: the grid
/// depends on the exact pixel size of what the server sent.
class ScrambledImage extends StatefulWidget {
  final ImageProvider provider;
  final PageScramble scramble;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Height / width of the picture, once it is known.
  final ValueChanged<double>? onAspectRatio;

  const ScrambledImage({
    super.key,
    required this.provider,
    required this.scramble,
    this.fit = BoxFit.fitWidth,
    this.width,
    this.height,
    this.placeholder,
    this.errorBuilder,
    this.onAspectRatio,
  });

  @override
  State<ScrambledImage> createState() => _ScrambledImageState();
}

class _ScrambledImageState extends State<ScrambledImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _result;
  Object? _error;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ScrambledImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider || oldWidget.scramble != widget.scramble) {
      _resolve();
    }
  }

  void _resolve() {
    _stopListening();
    final generation = ++_generation;
    final stream = widget.provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, _) async {
        // The stream keeps its own image: work on a copy, so disposing ours never touches the cache's.
        final copy = info.image.clone();
        try {
          final composed = await PageScrambler.compose(copy, widget.scramble);
          if (!mounted || generation != _generation) {
            composed.dispose();
            return;
          }
          final old = _result;
          setState(() {
            _result = composed;
            _error = null;
          });
          old?.dispose();
          if (composed.width > 0) widget.onAspectRatio?.call(composed.height / composed.width);
        } catch (e) {
          if (mounted && generation == _generation) setState(() => _error = e);
        } finally {
          copy.dispose();
        }
      },
      onError: (error, _) {
        if (mounted && generation == _generation) setState(() => _error = error);
      },
    );
    _stream = stream..addListener(_listener!);
  }

  void _stopListening() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _generation++;
    _stopListening();
    _result?.dispose();
    _result = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ?? const SizedBox.shrink();
    }

    final image = _result;
    if (image == null) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height ?? (widget.width != null ? widget.width! * 1.4 : null),
            child: const ColoredBox(color: Color(0xFF000000)),
          );
    }

    return RawImage(
      image: image,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}
