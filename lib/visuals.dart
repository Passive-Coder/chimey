import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const cyan = Color(0xff96e8ee);
const muted = Color(0xff8e929f);
const surface = Color(0xff12141b);

class EdgeLight extends StatefulWidget {
  const EdgeLight({
    super.key,
    required this.clock,
    required this.level,
    required this.frequency,
    required this.edges,
    required this.active,
    required this.reducedMotion,
  });
  final Animation<double> clock;
  final double level, frequency;
  final List<double> edges;
  final bool active, reducedMotion;
  @override
  State<EdgeLight> createState() => _EdgeLightState();
}

class _EdgeLightState extends State<EdgeLight> {
  ui.FragmentShader? shader;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/aurora.frag');
      if (mounted) setState(() => shader = program.fragmentShader());
    } catch (_) {
      // Software/test renderers use the continuous gradient fallback.
    }
  }

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _EdgePainter(
          shader,
          widget.clock,
          widget.level,
          widget.frequency,
          widget.edges,
          widget.active,
          widget.reducedMotion,
        ),
      ),
    ),
  );
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(
    this.shader,
    this.clock,
    this.level,
    this.frequency,
    this.edges,
    this.active,
    this.reducedMotion,
  ) : super(repaint: clock);
  final ui.FragmentShader? shader;
  final Animation<double> clock;
  final double level, frequency;
  final List<double> edges;
  final bool active, reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    if (shader case final s?) {
      final values = [
        size.width,
        size.height,
        reducedMotion ? 0.0 : clock.value * 120,
        level,
        frequency,
        ...edges,
        active ? 0.95 : 0.12,
        reducedMotion ? 8.0 : clock.value * 120,
      ];
      for (var i = 0; i < values.length; i++) {
        s.setFloat(i, values[i]);
      }
      canvas.drawRect(Offset.zero & size, Paint()..shader = s);
    } else {
      final rect = (Offset.zero & size).deflate(2);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = const SweepGradient(
          colors: [
            Color(0xff659cff),
            Color(0xffb081ff),
            Color(0xffee79b0),
            Color(0xffffac7e),
            cyan,
            Color(0xff659cff),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(22)),
        paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(22)),
        paint..maskFilter = null,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

class SoundField extends StatelessWidget {
  const SoundField({
    super.key,
    required this.clock,
    required this.level,
    required this.frequency,
    required this.active,
    required this.reducedMotion,
  });
  final Animation<double> clock;
  final double level, frequency;
  final bool active, reducedMotion;
  @override
  Widget build(BuildContext context) => Semantics(
    label: active ? 'Animated listening sound field' : 'Paused sound field',
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _FieldPainter(clock, level, frequency, active, reducedMotion),
        size: const Size(350, 240),
      ),
    ),
  );
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(
    this.clock,
    this.level,
    this.frequency,
    this.active,
    this.reducedMotion,
  ) : super(repaint: clock);
  final Animation<double> clock;
  final double level, frequency;
  final bool active, reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width * 0.32, size.height * 0.44);
    final t = reducedMotion || !active ? 0.0 : clock.value * 120;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xff748cdd).withValues(alpha: active ? .13 : .03),
          const Color(0xff9f73e0).withValues(alpha: .04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.8));
    canvas.drawCircle(center, r * 1.8, glow);
    for (var i = 0; i < 31; i++) {
      final latitude = -1.0 + i / 15;
      final breadth = math.sqrt(math.max(0, 1 - latitude * latitude));
      final path = Path();
      for (var j = 0; j <= 100; j++) {
        final x = -1 + j / 50;
        final arch = math.sqrt(math.max(0, 1 - x * x));
        final wave =
            math.sin(x * (7 + frequency * 12) + t * 1.1 + i * .25) *
            math.sin(arch * math.pi) *
            (2 + level * 9);
        final px = center.dx + x * r * breadth;
        final py =
            center.dy +
            latitude * r * .85 +
            arch * 12 * math.sin(t * .3) +
            wave;
        if (j == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .85
        ..shader = LinearGradient(
          colors: [
            const Color(0xff6e98dc).withValues(alpha: .15),
            cyan.withValues(alpha: active ? .58 : .18),
            const Color(0xffb38cde).withValues(alpha: .4),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawPath(path, paint);
    }
    for (var i = 0; i < 72; i++) {
      final a = i * 2.39996;
      final radius = r * math.sqrt(i / 72) * 1.6;
      final point =
          center +
          Offset(math.cos(a + t * .015), math.sin(a + t * .015)) * radius;
      canvas.drawCircle(
        point,
        i % 7 == 0 ? 1.1 : .55,
        Paint()..color = cyan.withValues(alpha: i % 7 == 0 ? .35 : .12),
      );
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) => true;
}

class Spectrum extends StatelessWidget {
  const Spectrum({super.key, required this.level, required this.frequency});
  final double level, frequency;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(
        40,
        (i) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height:
                  3 +
                  24 *
                      level *
                      (.3 + .7 * math.sin(i * .42 + frequency * 5).abs()),
              decoration: BoxDecoration(
                color: cyan.withValues(alpha: .25 + .55 * i / 40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
