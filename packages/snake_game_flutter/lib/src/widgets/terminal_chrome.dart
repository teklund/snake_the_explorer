import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A cosmetic wrapper that gives its [child] the appearance of a desktop
/// terminal window. The title bar style adapts to the host platform:
///
/// - **macOS**: Traffic-light dots (red/yellow/green) on the left.
/// - **Windows**: Minimise/maximise/close squares on the right.
/// - **Linux**: Simple close dot on the right.
/// - **Mobile / Web**: No title bar (full-screen terminal experience).
class TerminalChrome extends StatelessWidget {
  /// The widget to display inside the terminal frame.
  final Widget child;

  /// Background color for the terminal content area.
  final Color backgroundColor;

  const TerminalChrome({
    super.key,
    required this.child,
    required this.backgroundColor,
  });

  static const _titleBarColor = Color(0xFF2D2D2D);
  static const _borderColor = Color(0xFF1A1A1A);
  static const _titleBarHeight = 32.0;
  static const _cornerRadius = 8.0;

  bool _showTitleBar(BuildContext context) {
    // Skip chrome on mobile and web — go full-screen terminal.
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasTitleBar = _showTitleBar(context);
    final radius = hasTitleBar ? _cornerRadius : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: hasTitleBar ? Border.all(color: _borderColor) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTitleBar) _buildTitleBar(),
            Flexible(
              child: Container(
                color: backgroundColor,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: _titleBarHeight,
      color: _titleBarColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        children: [
          // Platform-specific window controls.
          _buildControls(),
          // Centered title.
          const Center(
            child: Text(
              'snake_the_explorer \u2014 bash',
              style: TextStyle(
                color: Color(0xFF999999),
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(const Color(0xFFFF5F57)), // close
              const SizedBox(width: 8),
              _dot(const Color(0xFFFEBC2E)), // minimise
              const SizedBox(width: 8),
              _dot(const Color(0xFF28C840)), // maximise
            ],
          ),
        ),
      TargetPlatform.windows => Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _windowsButton('\u2500'), // minimise (─)
              const SizedBox(width: 12),
              _windowsButton('\u25a1'), // maximise (□)
              const SizedBox(width: 12),
              _windowsButton('\u2715', // close (✕)
                  color: const Color(0xFFFF5F57)),
            ],
          ),
        ),
      TargetPlatform.linux => Align(
          alignment: Alignment.centerRight,
          child: _dot(const Color(0xFFFF5F57)),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _windowsButton(String symbol, {Color color = const Color(0xFF999999)}) {
    return Text(
      symbol,
      style: TextStyle(
        color: color,
        fontFamily: 'JetBrainsMono',
        fontSize: 12,
        decoration: TextDecoration.none,
      ),
    );
  }
}
