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

/// SharedPreferences key used to track whether the controls overlay has been shown.
const _controlsSeenPrefsKey = 'controls_seen';

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

  CrtTheme _theme = CrtTheme.greenPhosphor;

  /// Whether the mute indicator toast is currently visible.
  bool _showMuteIndicator = false;

  /// Whether the controls help overlay is visible.
  bool _showControls = false;

  /// Whether the reduced-motion accessibility preference is active.
  /// Updated in [build] from [MediaQuery]; read in event handlers.
  bool _reducedMotion = false;

  /// Whether the keyboard was the last input method used. Used to hide the
  /// D-pad and mouse cursor for immersion on desktop.
  bool _keyboardUsed = false;

  /// Tracks whether we injected a pause when the app went to the background,
  /// to avoid double-toggling on resume.
  bool _didPauseForBackground = false;

  /// Drives the cursor blink animation. Repeats a 0.0 -> 1.0 cycle every
  /// 530 ms (standard terminal blink rate).
  late final AnimationController _cursorBlinkController;

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
    _loadMuteSetting();
    _loadControlsFlag();
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
  // App lifecycle — auto-pause on background
  // -------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Inject a pause action so the game pauses when the app goes to the
      // background. Clear the queue first to avoid a double-toggle if the
      // player happened to press pause at the same moment.
      if (_loop != null && !_quit && !_didPauseForBackground) {
        _inputProvider.restore();
        _inputProvider.handleSwipe(InputAction.pause);
        _didPauseForBackground = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      _didPauseForBackground = false;
    }
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
  // Controls overlay
  // -------------------------------------------------------------------------

  Future<void> _loadControlsFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_controlsSeenPrefsKey) ?? false) && mounted) {
      setState(() => _showControls = true);
    }
  }

  Future<void> _dismissControls() async {
    setState(() => _showControls = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_controlsSeenPrefsKey, true);
  }

  // -------------------------------------------------------------------------
  // Mobile detection
  // -------------------------------------------------------------------------

  /// Detects touch-primary web contexts that [defaultTargetPlatform] might miss
  /// (e.g. iPads in desktop mode report as [TargetPlatform.macOS]).
  /// Uses 900 dp as the viewport threshold to include tablets (iPads are
  /// typically 768 dp on the short side in landscape).
  static bool _isMobileWeb(BuildContext context) {
    if (!kIsWeb) return false;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return shortestSide <= 900;
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

    // Skip particles and score labels when reduced-motion is enabled.
    if (!_reducedMotion) {
      // The grid position from core uses a +1 offset for the border.
      _particleKey.currentState?.spawnEvent(
        data.event,
        col: data.col + 1,
        row: data.row + 1,
        value: data.value,
      );
    }
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
    if (!_keyboardUsed) setState(() => _keyboardUsed = true);

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Dismiss the controls overlay on any key press.
      if (_showControls) {
        _dismissControls();
        return;
      }
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
      // ? (or /) shows the controls overlay.
      if (event.character == '?' || event.logicalKey == LogicalKeyboardKey.slash) {
        setState(() => _showControls = true);
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
    // Cache the accessibility preference so event handlers can read it without
    // a BuildContext (they run on the game loop, not inside build).
    _reducedMotion = MediaQuery.of(context).disableAnimations;

    return PopScope(
      // When the controls overlay is up, intercept the system back gesture to
      // dismiss it instead of exiting the app.
      canPop: !_showControls,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showControls) _dismissControls();
      },
      child: MouseRegion(
        cursor: _keyboardUsed ? SystemMouseCursors.none : SystemMouseCursors.basic,
        onHover: (_) {
          if (_keyboardUsed) setState(() => _keyboardUsed = false);
        },
        child: Listener(
          onPointerDown: (_) {
            if (_keyboardUsed) setState(() => _keyboardUsed = false);
          },
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: SwipeDetector(
        // When the controls overlay is up, redirect all swipe/tap actions to
        // dismiss it rather than forwarding them to the game.
        onSwipe: _showControls
            ? (_) => _dismissControls()
            : _inputProvider.handleSwipe,
        child: Container(
          color: _theme.backgroundColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxColumns = (constraints.maxWidth / _cellWidth).floor();
              final maxRows = (constraints.maxHeight / _cellHeight).floor();

              if (maxColumns < 20 || maxRows < 10) {
                return Center(
                  child: Text(
                    'Terminal too small\nResize window...',
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

              // Cap the game board at classic console dimensions. The canvas
              // is then centered (letterboxed) on all platforms, so walls
              // always reach the canvas edges without floating-point gaps.
              final gameColumns = maxColumns.clamp(20, 80);
              final gameRows = maxRows.clamp(10, 40);

              // Start a game if none is running yet.
              final r = _renderer;
              if (r == null && !_starting) {
                _starting = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startGame(gameColumns, gameRows);
                });
              }

              if (_quit) {
                // Render quit screen in terminal style — monospace text on
                // dark background, matching the CRT aesthetic.
                // Tapping anywhere restarts the game.
                final quitColor = _theme.mapColor(AnsiColor.green);
                final mutedColor = _theme.mapColor(AnsiColor.darkGray);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _startGame(gameColumns, gameRows),
                  child: Center(
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
                            Text(
                              '[ Play Again ]',
                              style: TextStyle(
                                color: quitColor,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
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

              Widget content = (isMobile && !_keyboardUsed)
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
                  // Controls help overlay — absorbs all input while visible.
                  if (_showControls)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismissControls,
                        child: _ControlsOverlay(theme: _theme),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      ),
      ),
    ),
  );
  }
}

// -----------------------------------------------------------------------------
// Controls help overlay
// -----------------------------------------------------------------------------

final class _ControlsOverlay extends StatelessWidget {
  final CrtTheme theme;

  const _ControlsOverlay({required this.theme});

  @override
  Widget build(BuildContext context) {
    final accentColor = theme.glowColor;
    final dimColor = theme.mapColor(AnsiColor.darkGray);

    final titleStyle = TextStyle(
      color: accentColor,
      fontFamily: 'JetBrainsMono',
      fontSize: 14,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.none,
    );
    final keyStyle = TextStyle(
      color: accentColor,
      fontFamily: 'JetBrainsMono',
      fontSize: 13,
      decoration: TextDecoration.none,
    );
    final actionStyle = TextStyle(
      color: dimColor,
      fontFamily: 'JetBrainsMono',
      fontSize: 13,
      decoration: TextDecoration.none,
    );
    final hintStyle = TextStyle(
      color: dimColor,
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      decoration: TextDecoration.none,
    );

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(
              color: theme.glowColor.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONTROLS', style: titleStyle),
              const SizedBox(height: 10),
              Text('KEYBOARD / GAMEPAD', style: hintStyle),
              const SizedBox(height: 6),
              _keyRow('↑↓←→ / WASD', 'Move', keyStyle, actionStyle),
              _keyRow('P', 'Pause / Resume', keyStyle, actionStyle),
              _keyRow('Q / Esc', 'Quit to menu', keyStyle, actionStyle),
              _keyRow('T', 'Cycle CRT theme', keyStyle, actionStyle),
              _keyRow('M', 'Mute / Unmute', keyStyle, actionStyle),
              _keyRow('?', 'Show controls', keyStyle, actionStyle),
              const SizedBox(height: 10),
              Text('TOUCH / SWIPE', style: hintStyle),
              const SizedBox(height: 6),
              _keyRow('Swipe', 'Move', keyStyle, actionStyle),
              _keyRow('Tap', 'Confirm / retry', keyStyle, actionStyle),
              _keyRow('D-pad', 'Move (hold to repeat)', keyStyle, actionStyle),
              const SizedBox(height: 14),
              Text('tap or press any key to dismiss', style: hintStyle),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _keyRow(
    String key,
    String action,
    TextStyle keyStyle,
    TextStyle actionStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 148, child: Text(key, style: keyStyle)),
          Text(action, style: actionStyle),
        ],
      ),
    );
  }
}
