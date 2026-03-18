import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:snake_game_core/snake_game_core.dart';

import '../game_color_map.dart';

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

    if (_particles.isEmpty && _shakeIntensity <= 0) {
      _ticker.stop();
      _lastTick = Duration.zero;
    }

    setState(() {});
  }

  /// Spawn particles for the given [event] at grid position ([col], [row]).
  void spawnEvent(GameEvent event, {int col = 0, int row = 0}) {
    final cx = (col + 0.5) * widget.cellWidth;
    final cy = (row + 0.5) * widget.cellHeight;

    switch (event) {
      case GameEvent.foodEaten:
        _spawnBurst(cx, cy, count: 8, speed: 60, colors: [
          mapAnsiColor(AnsiColor.green),
          mapAnsiColor(AnsiColor.brightGreen),
        ]);
      case GameEvent.bonusEaten:
        _spawnBurst(cx, cy, count: 14, speed: 90, colors: [
          mapAnsiColor(AnsiColor.yellow),
          mapAnsiColor(AnsiColor.cyan),
          Colors.white,
        ]);
      case GameEvent.shrinkPillEaten:
        _spawnBurst(cx, cy, count: 10, speed: 70, colors: [
          mapAnsiColor(AnsiColor.magenta),
          Colors.white70,
        ]);
      case GameEvent.combo:
        _spawnBurst(cx, cy, count: 18, speed: 100, colors: [
          mapAnsiColor(AnsiColor.yellow),
          mapAnsiColor(AnsiColor.red),
          Colors.white,
        ]);
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
    }

    if (!_ticker.isActive) {
      _ticker.start();
    }
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
