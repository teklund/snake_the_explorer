import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snake_game_core/snake_game_core.dart';

import '../crt_theme.dart';
import '../flutter_input_provider.dart';
import '../flutter_renderer.dart';
import '../sound_manager.dart';
import 'console_grid_painter.dart';
import 'crt_overlay.dart';
import 'dpad_widget.dart';
import 'particle_overlay.dart';
import 'swipe_detector.dart';
import 'terminal_chrome.dart';

/// SharedPreferences key used to persist the selected CRT theme.
const _themePrefsKey = 'crt_theme';

/// SharedPreferences key used to persist the sound mute setting.
const _mutePrefsKey = 'sound_muted';

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

class _ConsoleGameWidgetState extends State<ConsoleGameWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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

  /// Tracks the orientation at the last build so rotation can be detected.
  Orientation? _lastOrientation;

  CrtTheme _theme = CrtTheme.greenPhosphor;

  /// Whether the mute indicator toast is currently visible.
  bool _showMuteIndicator = false;

  /// Drives the cursor blink animation. Repeats a 0.0 -> 1.0 cycle every
  /// 530 ms (standard terminal blink rate).
  late final AnimationController _cursorBlinkController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat();
    _cursorBlinkController.addListener(() {
      // Only rebuild when the cursor is actually visible — avoids unnecessary
      // repaints during gameplay.
      if (_renderer?.cursorVisible ?? false) {
        setState(() {});
      }
    });
    _loadTheme();
    _loadMuteSetting();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cursorBlinkController.dispose();
    _loop?.stop();
    _sound.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Orientation change handling
  // -------------------------------------------------------------------------

  /// Called by [WidgetsBindingObserver] when window metrics change (e.g. on
  /// device rotation). Automatically pauses an active game so the snake
  /// doesn't crash while the screen re-lays out.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Derive orientation from the platform window's physical size, which is
    // available synchronously without a BuildContext.
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return;
    final size = view.physicalSize;
    final newOrientation =
        size.width >= size.height ? Orientation.landscape : Orientation.portrait;

    if (_lastOrientation != null &&
        _lastOrientation != newOrientation &&
        _renderer != null &&
        !_quit) {
      // Orientation changed mid-game — pause so the player doesn't lose
      // control while the grid re-centers in the new layout.
      _inputProvider.handleSwipe(InputAction.pause);
    }
    _lastOrientation = newOrientation;
  }

  // -------------------------------------------------------------------------
  // Theme persistence
  // -------------------------------------------------------------------------

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themePrefsKey);
    if (name != null && mounted) {
      setState(() => _theme = CrtTheme.fromName(name));
    }
  }

  Future<void> _saveTheme(CrtTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, theme.name);
  }

  void _cycleTheme() {
    final next = _theme.next;
    setState(() => _theme = next);
    // Clear the text painter cache so colors are rebuilt for the new theme.
    ConsoleGridPainter.clearCache();
    _saveTheme(next);
  }

  // -------------------------------------------------------------------------
  // Sound mute persistence
  // -------------------------------------------------------------------------

  Future<void> _loadMuteSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final muted = prefs.getBool(_mutePrefsKey) ?? false;
    if (mounted) {
      setState(() => _sound.muted = muted);
    }
  }

  Future<void> _saveMuteSetting(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutePrefsKey, muted);
  }

  void _toggleMute() {
    final nowMuted = _sound.toggleMute();
    _saveMuteSetting(nowMuted);
    setState(() => _showMuteIndicator = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showMuteIndicator = false);
    });
  }

  // -------------------------------------------------------------------------
  // Mobile detection
  // -------------------------------------------------------------------------

  /// Detects mobile web browsers that [defaultTargetPlatform] might miss
  /// (e.g. iPads in desktop mode report as [TargetPlatform.macOS]).
  /// Falls back to a narrow-viewport heuristic when running on the web.
  static bool _isMobileWeb(BuildContext context) {
    if (!kIsWeb) return false;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    // Treat viewports whose shortest side is <=600 dp as mobile/tablet.
    return shortestSide <= 600;
  }

  // -------------------------------------------------------------------------
  // Game events
  // -------------------------------------------------------------------------

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

    // Haptic feedback on mobile platforms only.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      switch (data.event) {
        case GameEvent.foodEaten:
          HapticFeedback.lightImpact();
        case GameEvent.bonusEaten:
        case GameEvent.shrinkPillEaten:
        case GameEvent.combo:
          HapticFeedback.mediumImpact();
        case GameEvent.death:
        case GameEvent.newHighScore:
          HapticFeedback.heavyImpact();
        case GameEvent.portalUsed:
          HapticFeedback.selectionClick();
      }
    }

    // The grid position from core uses a +1 offset for the border,
    // so pass the raw col/row — the particle overlay maps to pixels.
    _particleKey.currentState?.spawnEvent(
      data.event,
      col: data.col + 1, // +1 for border offset
      row: data.row + 1,
    );
  }

  // -------------------------------------------------------------------------
  // Game lifecycle
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Keyboard handling
  // -------------------------------------------------------------------------

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Intercept the T key for theme cycling before forwarding to the game.
      if (event.logicalKey == LogicalKeyboardKey.keyT) {
        _cycleTheme();
        return;
      }
      // Intercept the M key for sound mute toggling.
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _toggleMute();
        return;
      }
    }
    _inputProvider.handleKeyEvent(event);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // SafeArea pads the game content so it stays within the visible area,
      // clear of notches, rounded corners, and system gesture bars.
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SwipeDetector(
          onSwipe: _inputProvider.handleSwipe,
          child: Container(
            color: _theme.backgroundColor,
            child: LayoutBuilder(
            builder: (context, constraints) {
              final maxColumns = (constraints.maxWidth / _cellWidth).floor();
              final maxRows = (constraints.maxHeight / _cellHeight).floor();

              // Seed _lastOrientation on the first build so that the initial
              // orientation is known before the first rotation event fires.
              final currentOrientation = constraints.maxWidth >= constraints.maxHeight
                  ? Orientation.landscape
                  : Orientation.portrait;
              _lastOrientation ??= currentOrientation;

              if (maxColumns < 20 || maxRows < 10) {
                // In portrait on a narrow phone the grid simply won't fit.
                // Show a friendly prompt rather than a generic error.
                final isPortrait = currentOrientation == Orientation.portrait;
                final message = isPortrait
                    ? 'Rotate your device\nfor the best experience'
                    : 'Terminal too small\nResize window...';
                return Center(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _theme.mapColor(AnsiColor.darkGray),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14,
                      decoration: TextDecoration.none,
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
                // Render quit screen in terminal style — monospace text on
                // dark background, matching the CRT aesthetic.
                final quitColor = _theme.mapColor(AnsiColor.green);
                final mutedColor = _theme.mapColor(AnsiColor.darkGray);
                return Center(
                  child: TerminalChrome(
                    backgroundColor: _theme.backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Thanks for playing!',
                            style: TextStyle(
                              color: quitColor,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 18,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$ _',
                            style: TextStyle(
                              color: mutedColor,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _startGame(maxColumns, maxRows),
                            child: Text(
                              '[ Play Again ]',
                              style: TextStyle(
                                color: quitColor,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (r == null) {
                return const SizedBox.shrink();
              }

              final canvasWidth = r.columns * _cellWidth;
              final canvasHeight = r.rows * _cellHeight;

              final gameCanvas = Semantics(
                label: 'Snake game canvas',
                excludeSemantics: true,
                child: ParticleOverlay(
                  key: _particleKey,
                  cellWidth: _cellWidth,
                  cellHeight: _cellHeight,
                  child: CrtOverlay(
                    glowColor: _theme.glowColor,
                    scanlineTint: _theme.scanlineTint,
                    child: CustomPaint(
                      painter: ConsoleGridPainter(
                        buffer: r.buffer,
                        cellWidth: _cellWidth,
                        cellHeight: _cellHeight,
                        theme: _theme,
                        cursorVisible: r.cursorVisible,
                        cursorRow: r.cursorRow,
                        cursorCol: r.cursorCol,
                        blinkPhase: _cursorBlinkController.value,
                      ),
                      size: Size(canvasWidth, canvasHeight),
                    ),
                  ),
                ),
              );

              // Show D-pad on native mobile AND mobile web.
              // On Flutter web, defaultTargetPlatform still reports
              // the underlying OS (iOS/Android), so a single platform
              // check covers both native and web mobile users.
              final isMobile =
                  defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android ||
                  _isMobileWeb(context);

              // In landscape the D-pad sits in the bottom-right corner.
              // In portrait it is centred at the bottom for easier one-handed
              // reach and to avoid overlapping the narrower game canvas.
              final isLandscape = currentOrientation == Orientation.landscape;
              final dpad = DpadWidget(onInput: _inputProvider.handleSwipe);

              Widget content = isMobile
                  ? Stack(
                      children: [
                        gameCanvas,
                        Positioned(
                          left: isLandscape ? null : 0,
                          right: isLandscape ? 24 : 0,
                          bottom: 24,
                          child: isLandscape ? dpad : Center(child: dpad),
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

              return Stack(
                children: [
                  Center(
                    child: TerminalChrome(
                      backgroundColor: _theme.backgroundColor,
                      child: content,
                    ),
                  ),
                  if (_showMuteIndicator)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showMuteIndicator ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _theme.glowColor),
                            ),
                            child: Text(
                              _sound.isMuted ? 'SOUND OFF' : 'SOUND ON',
                              style: TextStyle(
                                color: _theme.glowColor,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  }
}
