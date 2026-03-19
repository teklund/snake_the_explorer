import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:snake_game_core/snake_game_core.dart';

import '../game_color_map.dart';

/// A floating score label that drifts upward and fades out.
final class _ScoreLabel {
  double x;
  double y;
  double life; // 1.0 → 0.0
  final double decay = 0.9; // life lost per second
  final String text;
  final Color color;

  _ScoreLabel({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
  }) : life = 1.0;
}

/// A single animated particle with position, velocity, and lifetime.
final class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life; // 0..1 — starts at 1, ticks down to 0
  final double decay; // life lost per second
  final Color color;
  final double size;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.decay,
    required this.color,
    required this.size,
  }) : life = 1.0;
}

/// Overlay that renders animated particles on top of the game canvas.
///
/// Call [spawnEvent] to emit particles at a grid position in response to
/// [GameEvent]s. The overlay uses a [Ticker] so particles animate smoothly
/// independent of the game loop frame rate.
class ParticleOverlay extends StatefulWidget {
  final double cellWidth;
  final double cellHeight;
  final Widget child;

  const ParticleOverlay({
    super.key,
    required this.cellWidth,
    required this.cellHeight,
    required this.child,
  });

  @override
  State<ParticleOverlay> createState() => ParticleOverlayState();
}

class ParticleOverlayState extends State<ParticleOverlay>
    with SingleTickerProviderStateMixin {
  final _particles = <_Particle>[];
  final _labels = <_ScoreLabel>[];
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final _rng = math.Random();

  // Screen shake state
  double _shakeIntensity = 0;
  double _shakeX = 0;
  double _shakeY = 0;
  static const _shakeDamping = 8.0; // decay per second

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (_lastTick == Duration.zero)
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 80.0 * dt; // gravity
      p.life -= p.decay * dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final l in _labels) {
      l.y -= 30.0 * dt; // drift upward
      l.life -= l.decay * dt;
    }
    _labels.removeWhere((l) => l.life <= 0);

    // Decay screen shake
    if (_shakeIntensity > 0) {
      _shakeIntensity = (_shakeIntensity - _shakeDamping * dt).clamp(0, 20);
      if (_shakeIntensity > 0.5) {
        _shakeX = (_rng.nextDouble() - 0.5) * 2 * _shakeIntensity;
        _shakeY = (_rng.nextDouble() - 0.5) * 2 * _shakeIntensity;
      } else {
        _shakeX = 0;
        _shakeY = 0;
        _shakeIntensity = 0;
      }
    }

    if (_particles.isEmpty && _labels.isEmpty && _shakeIntensity <= 0) {
      _ticker.stop();
      _lastTick = Duration.zero;
    }

    setState(() {});
  }

  /// Spawn particles and score labels for [event] at grid position ([col], [row]).
  /// [value] carries event-specific numeric data (score delta, combo count).
  void spawnEvent(GameEvent event, {int col = 0, int row = 0, int value = 0}) {
    final cx = (col + 0.5) * widget.cellWidth;
    final cy = (row + 0.5) * widget.cellHeight;

    switch (event) {
      case GameEvent.foodEaten:
        _spawnBurst(cx, cy, count: 8, speed: 60, colors: [
          mapAnsiColor(AnsiColor.green),
          mapAnsiColor(AnsiColor.brightGreen),
        ]);
        _spawnLabel(cx, cy, text: '+$value', color: mapAnsiColor(AnsiColor.brightGreen));
      case GameEvent.bonusEaten:
        _spawnBurst(cx, cy, count: 14, speed: 90, colors: [
          mapAnsiColor(AnsiColor.yellow),
          mapAnsiColor(AnsiColor.cyan),
          Colors.white,
        ]);
        _spawnLabel(cx, cy, text: '+$value', color: mapAnsiColor(AnsiColor.yellow));
      case GameEvent.shrinkPillEaten:
        _spawnBurst(cx, cy, count: 10, speed: 70, colors: [
          mapAnsiColor(AnsiColor.magenta),
          Colors.white70,
        ]);
        _spawnLabel(cx, cy, text: 'SHRINK', color: mapAnsiColor(AnsiColor.magenta));
      case GameEvent.combo:
        _spawnBurst(cx, cy, count: 18, speed: 100, colors: [
          mapAnsiColor(AnsiColor.yellow),
          mapAnsiColor(AnsiColor.red),
          Colors.white,
        ]);
        _spawnLabel(cx, cy, text: 'COMBO x$value', color: mapAnsiColor(AnsiColor.yellow));
      case GameEvent.portalUsed:
        _spawnRing(cx, cy, count: 12, colors: [
          mapAnsiColor(AnsiColor.cyan),
          mapAnsiColor(AnsiColor.magenta),
        ]);
      case GameEvent.death:
        _spawnExplosion(cx, cy);
        _shakeIntensity = 12.0;
      case GameEvent.newHighScore:
        _spawnBurst(cx, cy, count: 24, speed: 120, colors: [
          mapAnsiColor(AnsiColor.yellow),
          Colors.white,
          const Color(0xFFFFCC00),
        ]);
        _spawnLabel(cx, cy, text: 'NEW BEST!', color: const Color(0xFFFFCC00));
    }

    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _spawnLabel(double cx, double cy, {required String text, required Color color}) {
    _labels.add(_ScoreLabel(
      x: cx + (_rng.nextDouble() - 0.5) * widget.cellWidth,
      y: cy,
      text: text,
      color: color,
    ));
  }

  void _spawnBurst(
    double cx,
    double cy, {
    required int count,
    required double speed,
    required List<Color> colors,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final v = speed * (0.5 + _rng.nextDouble() * 0.5);
      _particles.add(_Particle(
        x: cx,
        y: cy,
        vx: math.cos(angle) * v,
        vy: math.sin(angle) * v - 30,
        decay: 1.5 + _rng.nextDouble(),
        color: colors[_rng.nextInt(colors.length)],
        size: 2.0 + _rng.nextDouble() * 2.0,
      ));
    }
  }

  void _spawnRing(
    double cx,
    double cy, {
    required int count,
    required List<Color> colors,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      _particles.add(_Particle(
        x: cx,
        y: cy,
        vx: math.cos(angle) * 50,
        vy: math.sin(angle) * 50,
        decay: 2.0,
        color: colors[i % colors.length],
        size: 2.5,
      ));
    }
  }

  void _spawnExplosion(double cx, double cy) {
    // Big burst of red/orange/yellow particles
    for (var i = 0; i < 30; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final v = 40 + _rng.nextDouble() * 120;
      _particles.add(_Particle(
        x: cx + (_rng.nextDouble() - 0.5) * 10,
        y: cy + (_rng.nextDouble() - 0.5) * 10,
        vx: math.cos(angle) * v,
        vy: math.sin(angle) * v - 40,
        decay: 0.8 + _rng.nextDouble() * 0.8,
        color: [
          mapAnsiColor(AnsiColor.red),
          mapAnsiColor(AnsiColor.yellow),
          const Color(0xFFFF8800),
          Colors.white,
        ][_rng.nextInt(4)],
        size: 2.0 + _rng.nextDouble() * 3.0,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ParticlePainter(_particles),
              ),
            ),
          ),
        if (_labels.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScoreLabelPainter(_labels),
              ),
            ),
          ),
      ],
    );

    if (_shakeIntensity > 0) {
      content = Transform.translate(
        offset: Offset(_shakeX, _shakeY),
        child: content,
      );
    }

    return content;
  }
}

final class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  const _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = p.color.withValues(alpha: p.life.clamp(0, 1));
      canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

final class _ScoreLabelPainter extends CustomPainter {
  final List<_ScoreLabel> labels;

  const _ScoreLabelPainter(this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in labels) {
      final alpha = l.life.clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: l.text,
          style: TextStyle(
            color: l.color.withValues(alpha: alpha),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrainsMono',
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(l.x - tp.width / 2, l.y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ScoreLabelPainter old) => true;
}
