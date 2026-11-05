import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';

// ============================================================================
// Shared mask geometry. Player (MaskedLayer), handles overlay and export all
// use THIS file, so preview and export always match.
// ============================================================================

const double kMaskMaxFeather = 50;
const double _kFeatherRefWidth = 340;

/// feather (0..50) -> gaussian sigma in pixels for a frame of [frameWidth].
/// Use the SAME function for preview and export.
double maskSigma(double feather, double frameWidth) =>
    feather * (frameWidth / _kFeatherRefWidth) / 2.2;

bool maskIsLine(String n) {
  final String s = n.toLowerCase();
  return s.contains('linear') || s.contains('split') || s.contains('horizontal');
}

bool maskIsMirror(String n) => n.toLowerCase().contains('mirror');

bool maskIsRect(String n) {
  final String s = n.toLowerCase();
  return s.contains('rect') || s.contains('square');
}

/// Closed shapes drawn inside [r].
Path maskShapePath(String name, Rect r, {double? corner}) {
  final String n = name.toLowerCase();
  final Offset c = r.center;
  if (n.contains('circle') || n.contains('ellipse') || n.contains('oval')) {
    return Path()..addOval(r);
  }
  if (n.contains('heart')) {
    final double w = r.width, h = r.height;
    return Path()
      ..moveTo(c.dx, r.top + h * 0.28)
      ..cubicTo(c.dx, r.top - h * 0.02, r.left, r.top + h * 0.02, r.left, r.top + h * 0.34)
      ..cubicTo(r.left, r.top + h * 0.62, c.dx - w * 0.1, r.top + h * 0.78, c.dx, r.bottom)
      ..cubicTo(c.dx + w * 0.1, r.top + h * 0.78, r.right, r.top + h * 0.62, r.right,
          r.top + h * 0.34)
      ..cubicTo(r.right, r.top + h * 0.02, c.dx, r.top - h * 0.02, c.dx, r.top + h * 0.28)
      ..close();
  }
  if (n.contains('star')) {
    final double rx = r.width / 2, ry = r.height / 2;
    final Path p = Path();
    for (int i = 0; i < 10; i++) {
      final double k = i.isEven ? 1.0 : 0.45;
      final double a = -math.pi / 2 + i * math.pi / 5;
      final Offset o = c + Offset(math.cos(a) * rx * k, math.sin(a) * ry * k);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }
  return Path()
    ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(corner ?? r.shortestSide * 0.1)));
}

/// Normalized mask transform (0..1 of the frame).
class MaskXform {
  const MaskXform({
    this.cx = 0.5,
    this.cy = 0.5,
    this.w = 0.5,
    this.h = 0.5,
    this.rot = 0.0,
    this.corner = 0.0,
  });

  final double cx, cy, w, h, rot, corner;

  factory MaskXform.fromProps(MaskProperties p) => MaskXform(
        cx: p.centerX,
        cy: p.centerY,
        w: p.width > 2.0 ? 0.5 : p.width,
        h: p.height > 2.0 ? 0.5 : p.height,
        rot: p.rotation,
        corner: p.cornerRadius,
      );

  MaskXform copyWith(
          {double? cx, double? cy, double? w, double? h, double? rot, double? corner}) =>
      MaskXform(
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        w: w ?? this.w,
        h: h ?? this.h,
        rot: rot ?? this.rot,
        corner: corner ?? this.corner,
      );
}

extension MaskPropsX on MaskProperties {
  bool get isActive => type != MaskType.none;

  MaskProperties withXform(
    MaskXform x, {
    MaskType? type,
    double? feather,
    bool? invert,
  }) =>
      MaskProperties(
        type: type ?? this.type,
        feather: feather ?? this.feather,
        centerX: x.cx,
        centerY: x.cy,
        width: x.w,
        height: x.h,
        rotation: x.rot,
        cornerRadius: x.corner,
        invert: invert ?? this.invert,
      );
}

/// Geometry of the mask in its own rotated space (origin = mask center).
class MaskGeometry {
  MaskGeometry(this.name, this.size, this.x);
  final String name;
  final Size size;
  final MaskXform x;

  bool get line => maskIsLine(name);
  bool get mirror => maskIsMirror(name);
  bool get rect => maskIsRect(name);
  bool get closed => !line && !mirror;

  Offset get c => Offset(x.cx * size.width, x.cy * size.height);
  double get hw => x.w * size.width / 2;
  double get hh => line ? 0 : x.h * size.height / 2;
  double get vhw => closed ? hw : size.width * 0.3;
  double get big => size.longestSide * 2;
  double get maxR => math.min(hw, hh);
  double get radiusPx => x.corner * maxR;

  Offset get feather => Offset(vhw + 34, 0);
  Offset get rotate => Offset(0, -hh - 28);
  Offset? get radius => rect ? Offset(-hw + 40 + radiusPx, -hh) : null;
  List<Offset> get corners => closed
      ? <Offset>[Offset(-hw, -hh), Offset(hw, -hh), Offset(hw, hh), Offset(-hw, hh)]
      : mirror
          ? <Offset>[Offset(-vhw, -hh), Offset(-vhw, hh)]
          : <Offset>[];

  Path shape() {
    if (line) return Path()..addRect(Rect.fromLTRB(-big, -big, big, 0));
    if (mirror) return Path()..addRect(Rect.fromLTRB(-big, -hh, big, hh));
    return maskShapePath(name, Rect.fromLTRB(-hw, -hh, hw, hh),
        corner: rect ? radiusPx : null);
  }
}