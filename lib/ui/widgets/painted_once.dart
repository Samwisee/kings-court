/// Something drawn once into a picture of its own, and shown from then on
/// as that picture: for big, still drawings (the felt, its pattern and
/// lamp) under things that move. On the web every frame draws the whole
/// screen again, so a pattern of hundreds of lines would be drawn afresh
/// for every frame of anything moving anywhere; as a picture it's one
/// copy.
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
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(ratio);
      for (final p in widget.painters) {
        p.paint(canvas, size);
      }
      final picture = recorder.endRecording();
      final image = picture.toImageSync((size.width * ratio).ceil(), (size.height * ratio).ceil());
      picture.dispose();
      _image?.dispose();
      _image = image;
      _drawn = key;
    } catch (_) {
      // No pictures here: drawn live instead.
      return null;
    }
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
