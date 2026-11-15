/// Small reusable animations: staggered entrances, counting numbers, a
/// progress ring, confetti and a "draw reel" for the random pick.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/format.dart';

/// Fades and slides its child in once. Give list items an [index] so they
/// appear one after another.
class FadeSlide extends StatefulWidget {
  const FadeSlide({super.key, required this.child, this.index = 0, this.dy = 0.08});

  final Widget child;
  final int index;

  /// Starting offset as a fraction of the child's height.
  final double dy;

  @override
  State<FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<FadeSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final steps = widget.index > 8 ? 8 : widget.index;
    final stagger = steps * 70;
    const base = 420;
    final total = base + stagger;
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(stagger / total, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: _curve.drive(Tween<Offset>(begin: Offset(0, widget.dy), end: Offset.zero)),
        child: widget.child,
      ),
    );
  }
}

/// A rupee amount that counts up (or down) to its value.
class AnimatedRupees extends StatelessWidget {
  const AnimatedRupees({super.key, required this.value, this.style, this.compact = false});

  final int value;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(compact ? rupeesCompact(n) : rupees(n), style: style);
      },
    );
  }
}

/// A circular progress indicator that animates to [progress] (0 to 1).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 84,
    this.strokeWidth = 9,
    this.color,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = progress.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: v,
              color: color ?? scheme.primary,
              track: trackColor ?? scheme.primary.withAlpha(34),
              stroke: strokeWidth,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 2 * pi, false, base);
    if (progress <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}

/// One burst of confetti that plays once when it appears. Put it in a [Stack]
/// above the content.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.seed = 7, this.count = 70});

  final int seed;
  final int count;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  _Particle(this.angle, this.speed, this.size, this.color, this.spin);

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const List<Color> _palette = <Color>[
    Color(0xFFF5B301),
    Color(0xFF14B8A6),
    Color(0xFF0F766E),
    Color(0xFFFFFFFF),
    Color(0xFFFB7185),
    Color(0xFF60A5FA),
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    _particles = <_Particle>[
      for (var i = 0; i < widget.count; i++)
        _Particle(
          -pi / 2 + (rng.nextDouble() - 0.5) * pi * 1.2,
          180 + rng.nextDouble() * 360,
          5 + rng.nextDouble() * 6,
          _palette[rng.nextInt(_palette.length)],
          (rng.nextDouble() - 0.5) * 12,
        ),
    ];
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_particles, _controller.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.35);
    final seconds = t * 2.2;
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();
    for (final p in particles) {
      final dx = cos(p.angle) * p.speed * seconds;
      final dy = sin(p.angle) * p.speed * seconds + 0.5 * 520 * seconds * seconds;
      final paint = Paint()..color = p.color.withAlpha((255 * fade).round());
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.spin * seconds);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// A slot-machine style reel that cycles through [candidates], slows down and
/// lands on [winner]. Calls [onFinished] exactly once when it stops.
class DrawReel extends StatefulWidget {
  const DrawReel({
    super.key,
    required this.candidates,
    required this.winner,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 3400),
  });

  final List<String> candidates;
  final String winner;
  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<DrawReel> createState() => _DrawReelState();
}

class _DrawReelState extends State<DrawReel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<String> _sequence;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final others = widget.candidates.where((c) => c != widget.winner).toList();
    final pool = others.isEmpty ? <String>[widget.winner] : others;
    const steps = 30;
    _sequence = <String>[
      for (var i = 0; i < steps; i++) pool[i % pool.length],
      widget.winner,
    ];
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_finished) {
          _finished = true;
          widget.onFinished();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final eased = Curves.easeOutQuart.transform(_controller.value);
        final index = min((eased * _sequence.length).floor(), _sequence.length - 1);
        final done = _controller.isCompleted;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: done ? scheme.tertiary.withAlpha(46) : scheme.primary.withAlpha(24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: done ? scheme.tertiary : scheme.primary.withAlpha(90), width: 2),
          ),
          child: Center(
            child: AnimatedScale(
              scale: done ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              child: Text(
                _sequence[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
