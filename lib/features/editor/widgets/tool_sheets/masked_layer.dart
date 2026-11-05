import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'mask_geometry.dart';

// ============================================================================
// 1) renderMaskMatte  : draws the stencil into a ui.Image (sync, fast)
// 2) MaskedLayer      : wraps the REAL video widget in the main player
// 3) writeMaskPng     : same matte as a PNG for FFmpeg export
//
// Why ShaderMask and not canvas.saveLayer?
//   video_player renders through a Texture (a compositing layer). A manual
//   saveLayer would NOT affect it. ShaderMask works with textures.
// ============================================================================

/// Renders the mask.
///  - opaque == false : white shape on transparent (alpha matte, for ShaderMask)
///  - opaque == true  : white = visible, black = hidden, no alpha (for FFmpeg)
/// [invert] is already applied. [scale] = device pixel ratio (preview) or 1 (export).
ui.Image renderMaskMatte({
  required String name,
  required MaskXform xform,
  required double feather,
  required bool invert,
  required Size size,
  double scale = 1.0,
  bool opaque = false,
}) {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec);
  c.scale(scale);

  final Rect rect = Offset.zero & size;
  final MaskGeometry g = MaskGeometry(name, size, xform);
  final double sigma = maskSigma(feather, size.width);
  final MaskFilter? blur = sigma <= 0 ? null : MaskFilter.blur(BlurStyle.normal, sigma);

  void shape(Paint p) {
    c.save();
    c.translate(g.c.dx, g.c.dy);
    c.rotate(xform.rot);
    c.drawPath(g.shape(), p..maskFilter = blur);
    c.restore();
  }

  if (opaque) {
    c.drawRect(rect, Paint()..color = invert ? Colors.white : Colors.black);
    shape(Paint()..color = invert ? Colors.black : Colors.white);
  } else if (invert) {
    c.saveLayer(rect, Paint());
    c.drawRect(rect, Paint()..color = Colors.white);
    shape(Paint()
      ..color = Colors.white
      ..blendMode = BlendMode.dstOut);
    c.restore();
  } else {
    shape(Paint()..color = Colors.white);
  }

  return rec.endRecording().toImageSync(
        (size.width * scale).ceil().clamp(1, 16384),
        (size.height * scale).ceil().clamp(1, 16384),
      );
}

/// Export helper: writes the matte as an opaque black/white PNG.
/// FFmpeg:  -i clip.mp4 -i mask.png -filter_complex
///   "[1:v]format=gray[m];[0:v][m]alphamerge[v]"   (then overlay [v] on the base)
/// Pass the real video size, so feather scales exactly like the preview.
Future<File> writeMaskPng({
  required MaskProperties props,
  required Size videoSize,
  required String path,
}) async {
  final ui.Image img = renderMaskMatte(
    name: props.type.name,
    xform: MaskXform.fromProps(props),
    feather: props.feather,
    invert: props.invert,
    size: videoSize,
    scale: 1,
    opaque: true,
  );
  final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}

// ----------------------------------------------------------------------------
// Widget
// ----------------------------------------------------------------------------
class MaskedLayer extends StatefulWidget {
  const MaskedLayer({
    super.key,
    required this.name,
    required this.xform,
    required this.feather,
    required this.invert,
    required this.child,
  });

  /// Convenience: build straight from the clip's MaskProperties.
  factory MaskedLayer.fromProps({
    Key? key,
    required MaskProperties? props,
    required Widget child,
  }) {
    final MaskProperties? p = props;
    if (p == null || p.type == MaskType.none) {
      return MaskedLayer(
        key: key,
        name: null,
        xform: const MaskXform(),
        feather: 0,
        invert: false,
        child: child,
      );
    }
    return MaskedLayer(
      key: key,
      name: p.type.name,
      xform: MaskXform.fromProps(p),
      feather: p.feather,
      invert: p.invert,
      child: child,
    );
  }

  final String? name; // null = no mask
  final MaskXform xform;
  final double feather;
  final bool invert;
  final Widget child;

  @override
  State<MaskedLayer> createState() => _MaskedLayerState();
}

class _MaskedLayerState extends State<MaskedLayer> {
  ui.Image? _img;
  Object? _key;

  @override
  Widget build(BuildContext context) {
    final String? name = widget.name;
    if (name == null) return widget.child;

    final double dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final Size size = box.biggest;
      if (!size.isFinite || size.isEmpty) return widget.child;

      final MaskXform x = widget.xform;
      final Object key = Object.hash(
        name, x.cx, x.cy, x.w, x.h, x.rot, x.corner,
        widget.feather, widget.invert, size, dpr,
      );
      if (key != _key || _img == null) {
        // Old image is left to the GC on purpose (raster thread may still use it).
        _img = renderMaskMatte(
          name: name,
          xform: x,
          feather: widget.feather,
          invert: widget.invert,
          size: size,
          scale: dpr,
        );
        _key = key;
      }
      final ui.Image img = _img!;

      return ShaderMask(
        blendMode: BlendMode.dstIn, // child * matte alpha
        shaderCallback: (Rect r) => ImageShader(
          img,
          TileMode.clamp,
          TileMode.clamp,
          (Matrix4.identity()
                ..translate(r.left, r.top)
                ..scale(1 / dpr, 1 / dpr))
              .storage,
        ),
        child: widget.child,
      );
    });
  }
}