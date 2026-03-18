import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:snake_game_core/snake_game_core.dart';

import '../flutter_input_provider.dart';
import '../flutter_renderer.dart';
import '../sound_manager.dart';
import 'console_grid_painter.dart';
import 'crt_overlay.dart';
import 'dpad_widget.dart';
import 'particle_overlay.dart';
import 'swipe_detector.dart';

/// A self-contained widget that hosts the entire Snake game.
///
/// On window resize the existing game continues at its original grid size,
/// centered within the new constraints. A fresh game is only started when
/// no game is running (initial launch or after quit -> Play Again).
class ConsoleGameWidget extends StatefulWidget {
  final ScoreRepository scoreRepo;

  const ConsoleGameWidget({super.key, required this.scoreRepo});

  @override
  State<ConsoleGameWidget> createState() => _ConsoleGameWidgetState();
}

class _ConsoleGameWidgetState extends State<ConsoleGameWidget> {
  static const _cellWidth = 10.0;
  static const _cellHeight = 18.0;

  final _focusNode = FocusNode();
  final _inputProvider = FlutterInputProvider();
  final _sound = SoundManager();
  final _particleKey = GlobalKey<ParticleOverlayState>();

  FlutterRenderer? _renderer;
  GameLoop? _loop;
  bool _quit = false;
  bool _starting = false;
  double _fadeOpacity = 0.0;
  int _gameGeneration = 0;

  @override
  void dispose() {
    _loop?.stop();
    _sound.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleGameEvent(GameEventData data) {
    switch (data.event) {
      case GameEvent.foodEaten:
        _sound.playEat();
      case GameEvent.bonusEaten:
      case GameEvent.shrinkPillEaten:
      case GameEvent.combo:
      case GameEvent.portalUsed:
        _sound.playBonus();
      case GameEvent.death:
        _sound.playDeath();
      case GameEvent.newHighScore:
        _sound.playVictory();
    }
    // The grid position from core uses a +1 offset for the border,
    // so pass the raw col/row — the particle overlay maps to pixels.
    _particleKey.currentState?.spawnEvent(
      data.event,
      col: data.col + 1, // +1 for border offset
      row: data.row + 1,
    );
  }

  void _startGame(int columns, int rows) {
    _loop?.stop();

    final renderer = FlutterRenderer(columns: columns, rows: rows);
    renderer.onFlush = () {
      if (mounted) setState(() {});
    };

    final sceneManager = SceneManager(
      initialScene: MenuScene(
        scoreRepo: widget.scoreRepo,
        boardColumns: columns,
        boardRows: rows,
        onEvent: _handleGameEvent,
      ),
      renderer: renderer,
      inputProvider: _inputProvider,
    );

    final loop = GameLoop(sceneManager);

    _renderer = renderer;
    _loop = loop;
    _quit = false;
    _starting = false;
    _fadeOpacity = 0.0;
    _gameGeneration++;

    // Trigger fade-in on next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _fadeOpacity = 1.0);
    });

    loop.run().then((_) {
      if (mounted) setState(() => _quit = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _inputProvider.handleKeyEvent,
      child: SwipeDetector(
        onSwipe: _inputProvider.handleSwipe,
        child: Container(
          color: const Color(0xFF0A0A0A),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxColumns = (constraints.maxWidth / _cellWidth).floor();
              final maxRows = (constraints.maxHeight / _cellHeight).floor();

              if (maxColumns < 20 || maxRows < 10) {
                return const Center(
                  child: Text(
                    'Window too small',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                );
              }

              // Start a game if none is running yet.
              final r = _renderer;
              if (r == null && !_starting) {
                _starting = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startGame(maxColumns, maxRows);
                });
              }

              if (_quit) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Thanks for playing!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _startGame(maxColumns, maxRows),
                        child: const Text(
                          'Play Again',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'JetBrainsMono',
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (r == null) {
                return const SizedBox.shrink();
              }

              final canvasWidth = r.columns * _cellWidth;
              final canvasHeight = r.rows * _cellHeight;

              final gameCanvas = ParticleOverlay(
                key: _particleKey,
                cellWidth: _cellWidth,
                cellHeight: _cellHeight,
                child: CrtOverlay(
                  child: CustomPaint(
                    painter: ConsoleGridPainter(
                      buffer: r.buffer,
                      cellWidth: _cellWidth,
                      cellHeight: _cellHeight,
                    ),
                    size: Size(canvasWidth, canvasHeight),
                  ),
                ),
              );

              final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android;

              Widget content = isMobile
                  ? Stack(
                      children: [
                        gameCanvas,
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: DpadWidget(
                            onInput: _inputProvider.handleSwipe,
                          ),
                        ),
                      ],
                    )
                  : gameCanvas;

              content = AnimatedOpacity(
                key: ValueKey(_gameGeneration),
                opacity: _fadeOpacity,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeIn,
                child: content,
              );

              return Center(child: content);
            },
          ),
        ),
      ),
    );
  }
}
