import 'package:flutter/material.dart';
import 'package:snake_game_core/snake_game_core.dart';

import '../flutter_input_provider.dart';
import '../flutter_renderer.dart';
import 'console_grid_painter.dart';
import 'swipe_detector.dart';

/// A self-contained widget that hosts the entire Snake game.
///
/// It calculates the grid size from its layout constraints, creates the
/// core game objects, runs the [GameLoop], and repaints on every frame.
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

  FlutterRenderer? _renderer;
  GameLoop? _loop;
  bool _quit = false;

  @override
  void dispose() {
    _loop?.stop();
    _focusNode.dispose();
    super.dispose();
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
      ),
      renderer: renderer,
      inputProvider: _inputProvider,
    );

    final loop = GameLoop(sceneManager);

    _renderer = renderer;
    _loop = loop;
    _quit = false;

    // The GameLoop.run() future completes when the game quits.
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
              final columns = (constraints.maxWidth / _cellWidth).floor();
              final rows = (constraints.maxHeight / _cellHeight).floor();

              if (columns < 20 || rows < 10) {
                return const Center(
                  child: Text(
                    'Window too small',
                    style: TextStyle(color: Colors.white54, fontFamily: 'monospace'),
                  ),
                );
              }

              // (Re)start if renderer doesn't exist or grid size changed.
              final r = _renderer;
              if (r == null || r.columns != columns || r.rows != rows) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startGame(columns, rows);
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
                          fontFamily: 'monospace',
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _startGame(columns, rows),
                        child: const Text(
                          'Play Again',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'monospace',
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

              return CustomPaint(
                painter: ConsoleGridPainter(
                  buffer: r.buffer,
                  cellWidth: _cellWidth,
                  cellHeight: _cellHeight,
                ),
                size: Size(
                  columns * _cellWidth,
                  rows * _cellHeight,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
