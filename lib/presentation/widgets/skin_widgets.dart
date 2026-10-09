import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../core/colors.dart';
import '../../core/motion.dart';

// ------------------------------------------------------------------ avatar

/// Flat, honest head-crop of the skin PNG (used as account avatar).
class SkinAvatar extends StatelessWidget {
  const SkinAvatar({super.key, this.skinPath, this.size = 44});

  final String? skinPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (skinPath == null || !File(skinPath!).existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: NovaColors.brandGradient,
        ),
        child: const Icon(Icons.person, color: NovaColors.bgDeep),
      );
    }
    return FutureBuilder<ui.Image>(
      future: _decode(skinPath!),
      builder: (context, snap) {
        if (snap.data == null) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: NovaColors.surfaceLight,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(
            size: Size(size, size),
            painter: _HeadPainter(snap.data!),
          ),
        );
      },
    );
  }

  static Future<ui.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _HeadPainter extends CustomPainter {
  _HeadPainter(this.img);
  final ui.Image img;

  @override
  void paint(Canvas canvas, Size size) {
    // Head front face in the 64x64 skin layout: (8,8,8,8).
    final src = Rect.fromLTRB(8, 8, 16, 16);
    canvas.imagePaint(
      img,
      src,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension on Canvas {
  void imagePaint(ui.Image img, Rect src, Rect dst) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    drawImageRect(img, src, dst, paint);
  }
}

// ------------------------------------------------------------------ 3D view

class _Box {
  const _Box(this.cx, this.cy, this.cz, this.w, this.h, this.d, this.uv);

  /// Center in model units (1 unit = 1 skin pixel), size w/h/d.
  final double cx, cy, cz, w, h, d;

  /// UV rectangles per face: [front, right, back, left, top, bottom]
  final List<Rect> uv;
}

const double _u = 1 / 64;

class SkinViewer3D extends StatefulWidget {
  const SkinViewer3D({super.key, required this.skinPath, this.slim = false});

  final String? skinPath;
  final bool slim;

  @override
  State<SkinViewer3D> createState() => _SkinViewer3DState();
}

class _SkinViewer3DState extends State<SkinViewer3D> {
  double _yaw = 0.5;
  double _pitch = 0.25;
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SkinViewer3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skinPath != widget.skinPath) _load();
  }

  Future<void> _load() async {
    if (widget.skinPath == null || !File(widget.skinPath!).existsSync()) {
      setState(() => _img = null);
      return;
    }
    final bytes = await File(widget.skinPath!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _img = frame.image);
  }

  static const List<_Box> _boxes = [
    // head 8x8x8 centered y=-16 (above body)
    _Box(0, -16, 0, 8, 8, 8, [
      Rect.fromLTRB(8, 8, 16, 16),
      Rect.fromLTRB(0, 8, 8, 16),
      Rect.fromLTRB(24, 8, 32, 16),
      Rect.fromLTRB(16, 8, 24, 16),
      Rect.fromLTRB(8, 0, 16, 8),
      Rect.fromLTRB(16, 0, 24, 8),
    ]),
    // body 8w 12h 4d centered y=-2
    _Box(0, -2, 0, 8, 12, 4, [
      Rect.fromLTRB(20, 20, 28, 32),
      Rect.fromLTRB(16, 20, 20, 32),
      Rect.fromLTRB(32, 20, 40, 32),
      Rect.fromLTRB(28, 20, 32, 32),
      Rect.fromLTRB(20, 16, 28, 20),
      Rect.fromLTRB(28, 16, 36, 20),
    ]),
    // right leg
    _Box(-2, 12, 0, 4, 12, 4, [
      Rect.fromLTRB(4, 20, 8, 32),
      Rect.fromLTRB(0, 20, 4, 32),
      Rect.fromLTRB(12, 20, 16, 32),
      Rect.fromLTRB(8, 20, 12, 32),
      Rect.fromLTRB(4, 16, 8, 20),
      Rect.fromLTRB(8, 16, 12, 20),
    ]),
    // left leg
    _Box(2, 12, 0, 4, 12, 4, [
      Rect.fromLTRB(20, 52, 24, 64),
      Rect.fromLTRB(16, 52, 20, 64),
      Rect.fromLTRB(28, 52, 32, 64),
      Rect.fromLTRB(24, 52, 28, 64),
      Rect.fromLTRB(20, 48, 24, 52),
      Rect.fromLTRB(24, 48, 28, 52),
    ]),
    // right arm
    _Box(-6, -2, 0, 4, 12, 4, [
      Rect.fromLTRB(44, 20, 48, 32),
      Rect.fromLTRB(40, 20, 44, 32),
      Rect.fromLTRB(52, 20, 56, 32),
      Rect.fromLTRB(48, 20, 52, 32),
      Rect.fromLTRB(44, 16, 48, 20),
      Rect.fromLTRB(48, 16, 52, 20),
    ]),
    // left arm
    _Box(6, -2, 0, 4, 12, 4, [
      Rect.fromLTRB(36, 52, 40, 64),
      Rect.fromLTRB(32, 52, 36, 64),
      Rect.fromLTRB(44, 52, 48, 64),
      Rect.fromLTRB(40, 52, 44, 64),
      Rect.fromLTRB(36, 48, 40, 52),
      Rect.fromLTRB(40, 48, 44, 52),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        setState(() {
          _yaw += d.delta.dx * 0.01;
          _pitch = (_pitch + d.delta.dy * 0.008)
              .clamp(-1.2, 1.2);
        });
      },
      child: Column(
        children: [
          Expanded(
            child: _img == null
                ? const Center(
                    child: Icon(Icons.person_off_outlined,
                        color: NovaColors.textSecondary, size: 48))
                : CustomPaint(
                    size: const Size.expand(),
                    painter: _PlayerPainter(
                      img: _img!,
                      yaw: _yaw,
                      pitch: _pitch,
                      slim: widget.slim,
                    ),
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'front',
                icon: const Icon(Icons.visibility_outlined,
                    color: NovaColors.textSecondary, size: 20),
                onPressed: () => setState(() {
                  _yaw = 0;
                  _pitch = 0.12;
                }),
              ),
              IconButton(
                tooltip: 'back',
                icon: const Icon(Icons.flip_camera_android_outlined,
                    color: NovaColors.textSecondary, size: 20),
                onPressed: () => setState(() {
                  _yaw = math.pi;
                  _pitch = 0.12;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Face {
  _Face(this.points, this.uv, this.depth, this.shade);
  final List<vm.Vector3> points; // projected 2D (z=0) in px
  final Rect uv;
  final double depth;
  final double shade;
}

class _PlayerPainter extends CustomPainter {
  _PlayerPainter({
    required this.img,
    required this.yaw,
    required this.pitch,
    required this.slim,
  });

  final ui.Image img;
  final double yaw;
  final double pitch;
  final bool slim;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 40;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final rot = vm.Matrix4.identity()
      ..rotateX(pitch)
      ..rotateY(yaw);

    final faces = <_Face>[];

    for (final box in _boxes) {
      final hw = (box.w * (slim && box.cx.abs() > 5 ? 0.75 : 1)) / 2;
      final hh = box.h / 2;
      final hd = box.d / 2;

      // 8 corners
      final c = <vm.Vector3>[
        vm.Vector3(-hw, -hh, -hd), // 0 front-top-left? define consistently below
        vm.Vector3(hw, -hh, -hd),
        vm.Vector3(hw, hh, -hd),
        vm.Vector3(-hw, hh, -hd),
        vm.Vector3(-hw, -hh, hd),
        vm.Vector3(hw, -hh, hd),
        vm.Vector3(hw, hh, hd),
        vm.Vector3(-hw, hh, hd),
      ].map((v) {
        final t = rot.transform3(
            vm.Vector3(v.x + box.cx, v.y + box.cy, v.z + box.cz));
        return t;
      }).toList();

      // faces: [front(-z), right(+x), back(+z), left(-x), top(-y), bottom(+y)]
      const faceIdx = [
        [0, 1, 2, 3], // front (-z)
        [1, 5, 6, 2], // right (+x)
        [5, 4, 7, 6], // back (+z)
        [4, 0, 3, 7], // left (-x)
        [4, 5, 1, 0], // top (-y)
        [3, 2, 6, 7], // bottom (+y)
      ];
      const normals = [
        [0.0, 0, -1],
        [1.0, 0, 0],
        [0.0, 0, 1],
        [-1.0, 0, 0],
        [0.0, -1, 0],
        [0.0, 1, 0],
      ];

      for (int f = 0; f < 6; f++) {
        final n = rot.transform3(vm.Vector3(
            normals[f][0], normals[f][1], normals[f][2]));
        // viewer at -z looking towards +z: face visible when normal z < 0
        if (n.z >= 0) continue;

        final idx = faceIdx[f];
        final proj = idx
            .map((i) => vm.Vector3(
                  cx + c[i].x * scale,
                  cy + c[i].y * scale,
                  c[i].z,
                ))
            .toList();
        final depth = proj.fold<double>(0, (a, p) => a + p.z) / 4;
        // simple directional shading
        final shade = 0.75 + 0.25 * n.y.abs();
        faces.add(_Face(proj, box.uv[f], depth, shade));
      }
    }

    faces.sort((a, b) => b.depth.compareTo(a.depth));

    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final face in faces) {
      final p0 = face.points[0];
      final p1 = face.points[1];
      final p3 = face.points[3];
      final ux = p1.x - p0.x;
      final uy = p1.y - p0.y;
      final vx = p3.x - p0.x;
      final vy = p3.y - p0.y;
      final m = vm.Matrix4(
        ux, uy, 0, 0,
        vx, vy, 0, 0,
        0, 0, 1, 0,
        p0.x, p0.y, 0, 1,
      );
      canvas.save();
      canvas.transform(m.storage);
      // draw unit square (0..1) mapped through affine -> quad; source = uv
      final src = Rect.fromLTRB(
        face.uv.left * img.width * _u,
        face.uv.top * img.height * _u,
        face.uv.right * img.width * _u,
        face.uv.bottom * img.height * _u,
      );
      canvas.drawImageRect(img, src, const Rect.fromLTRB(0, 0, 1, 1), paint);
      // shading overlay
      canvas.drawRect(
        const Rect.fromLTRB(0, 0, 1, 1),
        Paint()..color = Colors.black.withOpacity((1 - face.shade) * 0.9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerPainter old) =>
      old.yaw != yaw || old.pitch != pitch || old.img != img;
}

/// Animated appearance helper reused by screens.
Widget staggered(int index, Widget child) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: NovaMotion.scale(
        Duration(milliseconds: 260 + index * 40)),
    curve: NovaMotion.standard,
    builder: (context, v, ch) => Opacity(
      opacity: v,
      child: ch,
    ),
    child: child,
  );
}


