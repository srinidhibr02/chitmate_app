/// The spinning wheel shown while a random draw is revealed.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// A prize wheel with one slice per candidate. It spins several times, slows
/// down with a ticking pointer and stops on [winner].
///
/// The winner is already decided before the wheel appears; the spin only
/// reveals it. If [winner] is not in [candidates] it is added as a slice.
class DrawWheel extends StatefulWidget {
  const DrawWheel({
    super.key,
    required this.candidates,
    required this.winner,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 4600),
    this.size = 268,
  });

  final List<String> candidates;
  final String winner;
  final VoidCallback onFinished;
  final Duration duration;
  final double size;

  @override
  State<DrawWheel> createState() => _DrawWheelState();
}

class _DrawWheelState extends State<DrawWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<String> _slices;
  late final int _winnerIndex;
  late final double _totalTurn; // radians the wheel turns clockwise
  int _lastTick = -1;
  bool _finished = false;
  bool _reduceMotion = false;

  double get _slice => 2 * pi / _slices.length;

  @override
  void initState() {
    super.initState();
    final seen = <String>{};
    _slices = <String>[
      for (final c in widget.candidates)
        if (seen.add(c)) c,
      if (!seen.contains(widget.winner)) widget.winner,
    ];
    _winnerIndex = _slices.indexOf(widget.winner);
    // Land somewhere inside the winning slice, not always dead centre.
    final jitter = (((widget.winner.hashCode % 7) / 6) - 0.5) * 0.6;
    final target = (_winnerIndex + 0.5 + jitter) * _slice;
    // Turning the wheel clockwise by t brings the part that was at angle -t
    // (measured clockwise from the top) under the pointer, so t must equal
    // -target modulo a full turn. Five full turns are added for the show.
    _totalTurn = 2 * pi * 5 - target;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_finished) {
          _finished = true;
          HapticFeedback.mediumImpact();
          widget.onFinished();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_controller.isAnimating && !_controller.isCompleted) {
      _reduceMotion = reduce;
      if (reduce) _controller.duration = const Duration(milliseconds: 500);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Which slice is under the pointer at wheel angle [turn].
  int _indexAt(double turn) {
    final a = (-turn) % (2 * pi);
    return (a / _slice).floor() % _slices.length;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeOutQuart.transform(_controller.value);
        final turn = _totalTurn * progress;
        final index = _indexAt(turn);
        final done = _controller.isCompleted;
        if (!done && index != _lastTick) {
          _lastTick = index;
          if (!_reduceMotion) HapticFeedback.selectionClick();
        }
        // The pointer is nudged back each time a slice edge passes it.
        final within = (((-turn) % (2 * pi)) % _slice) / _slice;
        final speed = _controller.isAnimating ? (1 - progress) : 0.0;
        final flick = done ? 0.0 : within * 0.55 * min(1.0, speed * 4);
        final shownIndex = done ? _winnerIndex : index;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: widget.size,
              height: widget.size + 14,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    top: 14,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: (done ? AppColors.gold : AppColors.teal)
                                .withAlpha(done ? 150 : 70),
                            blurRadius: done ? 34 : 18,
                            spreadRadius: done ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: turn,
                        child: CustomPaint(
                          painter: _WheelPainter(
                            slices: _slices,
                            highlight: done ? _winnerIndex : null,
                            textColor: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Centre hub.
                  Positioned(
                    top: 14 + widget.size / 2 - 26,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surface,
                        border: Border.all(color: AppColors.gold, width: 4),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.currency_rupee_rounded,
                          color: AppColors.goldDark, size: 26),
                    ),
                  ),
                  // Pointer at the top.
                  Positioned(
                    top: 0,
                    child: Transform.rotate(
                      angle: flick,
                      alignment: Alignment.topCenter,
                      child: const CustomPaint(size: Size(30, 34), painter: _PointerPainter()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AnimatedScale(
              scale: done ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: Text(
                _slices[shownIndex],
                key: const Key('wheel-label'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: done ? AppColors.goldDark : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

const List<Color> _sliceColors = <Color>[
  Color(0xFF0F766E),
  Color(0xFF14B8A6),
  Color(0xFF0B4F4A),
  Color(0xFFF5B301),
  Color(0xFF2DD4BF),
];

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.slices, required this.highlight, required this.textColor});

  final List<String> slices;
  final int? highlight;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final n = slices.length;
    final a = 2 * pi / n;
    final rect = Rect.fromCircle(center: c, radius: r - 6);

    for (var i = 0; i < n; i++) {
      // Slice 0 starts at the top (-90 degrees) and they run clockwise.
      final start = -pi / 2 + i * a;
      var color = _sliceColors[i % _sliceColors.length];
      if (n % _sliceColors.length == 1 && i == n - 1) color = _sliceColors[1];
      final dim = highlight != null && highlight != i;
      final paint = Paint()
        ..color = highlight == i ? AppColors.gold : (dim ? color.withAlpha(120) : color);
      canvas.drawArc(rect, start, a, true, paint);
      canvas.drawArc(
        rect,
        start,
        a,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
      if (n <= 14) {
        final onLight = highlight == i || color == const Color(0xFFF5B301) || color == const Color(0xFF2DD4BF);
        _label(canvas, c, r, start + a / 2, slices[i], onLight ? const Color(0xFF123B38) : Colors.white, n);
      }
    }
    // Rim and pegs.
    canvas.drawCircle(
      c,
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white,
    );
    for (var i = 0; i < n; i++) {
      final ang = -pi / 2 + i * a;
      canvas.drawCircle(
        c + Offset(cos(ang), sin(ang)) * (r - 3),
        3.2,
        Paint()..color = AppColors.goldDark,
      );
    }
  }

  void _label(Canvas canvas, Offset c, double r, double angle, String text, Color color, int n) {
    final maxWidth = r * 0.55;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: n > 8 ? 11 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    // Text runs outward from the hub along the slice's middle line.
    tp.paint(canvas, Offset(r * 0.30, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.highlight != highlight || old.slices != slices || old.textColor != textColor;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, Paint()..color = AppColors.gold);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.goldDark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
