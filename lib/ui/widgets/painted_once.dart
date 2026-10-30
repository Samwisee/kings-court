/// Something drawn once into a picture of its own, and shown from then on
/// as that picture: for big, still drawings (the felt, its pattern and
/// lamp) under things that move. On the web every frame draws the whole
/// screen again, so a pattern of hundreds of lines would be drawn afresh
/// for every frame of anything moving anywhere; as a picture it's one
/// copy.
///
/// Drawing the picture is slow (a whole screen of pattern, at once), so
/// the last two are kept and shared: the felt muted on the front page and
/// full on the table, or a style looked at again in the Livery page, come
/// back without drawing again. And [PaintedOnce.ready] draws one ahead of
/// time, at a moment that suits (the table's felt the moment Start is
/// pressed, before the walk in begins, so the walk in doesn't stop for it).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// [painters], in order, drawn once at this size and the screen's
/// density into a picture, and drawn again only when [id] or the size
/// changes.
class PaintedOnce extends StatefulWidget {
  const PaintedOnce({super.key, required this.id, required this.painters});

  /// What's drawn: a new one draws it again.
  final Object id;
  final List<CustomPainter> painters;

  /// The pictures kept, newest last: a handle each, cloned for each
  /// widget showing one, so dropping one from here never pulls a picture
  /// out from under the screen.
  static final _kept = <Object, ui.Image>{};
  // Two: the felt muted and full. Each is a whole screen of pixels (about
  // 12 MB on a phone), and an installed web app on iOS has little memory
  // for pictures before drawing stalls.
  static const _most = 2;

  /// The size and density the last picture was drawn at.
  static (Size, double)? _lastAt;

  static ui.Image? _take(Object key) {
    final image = _kept.remove(key);
    if (image == null) return null;
    _kept[key] = image;
    return image.clone();
  }

  static void _keep(Object key, ui.Image image) {
    _kept.remove(key)?.dispose();
    _kept[key] = image;
    while (_kept.length > _most) {
      _kept.remove(_kept.keys.first)!.dispose();
    }
  }

  static ui.Image? _draw(List<CustomPainter> painters, Size size, double ratio) {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(ratio);
      for (final p in painters) {
        p.paint(canvas, size);
      }
      final picture = recorder.endRecording();
      final image = picture.toImageSync((size.width * ratio).ceil(), (size.height * ratio).ceil());
      picture.dispose();
      return image;
    } catch (_) {
      // No pictures here: drawn live instead.
      return null;
    }
  }

  /// Draws [painters] for [id] now, at the size the last picture was, so
  /// it's ready when it's shown: unless it's kept already.
  static void ready(Object id, List<CustomPainter> painters) {
    final at = _lastAt;
    if (at == null) return;
    final key = (id, at.$1, at.$2);
    if (_kept.containsKey(key)) return;
    final image = _draw(painters, at.$1, at.$2);
    if (image != null) _keep(key, image);
  }

  @override
  State<PaintedOnce> createState() => _PaintedOnceState();
}

class _PaintedOnceState extends State<PaintedOnce> {
  ui.Image? _image;
  Object? _drawn;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  ui.Image? _imageFor(Size size, double ratio) {
    final key = (widget.id, size, ratio);
    if (key == _drawn && _image != null) return _image;
    if (size.isEmpty || !size.isFinite) return null;
    var image = PaintedOnce._take(key);
    if (image == null) {
      final drawn = PaintedOnce._draw(widget.painters, size, ratio);
      if (drawn == null) return null;
      PaintedOnce._keep(key, drawn);
      image = drawn.clone();
    }
    _image?.dispose();
    _image = image;
    _drawn = key;
    PaintedOnce._lastAt = (size, ratio);
    return _image;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      final image = _imageFor(size, ratio);
      if (image == null) {
        return Stack(fit: StackFit.expand, children: [
          for (final p in widget.painters) CustomPaint(painter: p, size: Size.infinite),
        ]);
      }
      return RawImage(image: image, width: size.width, height: size.height, fit: BoxFit.fill);
    });
  }
}
