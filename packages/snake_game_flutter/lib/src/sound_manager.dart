import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Manages retro-style sound effects for the game.
///
/// Generates simple sine-wave tones as in-memory WAV data — no external
/// asset files required. Each effect is a short beep/buzz at a characteristic
/// frequency to evoke classic 8-bit game audio.
final class SoundManager {
  final AudioPlayer _eatPlayer = AudioPlayer();
  final AudioPlayer _bonusPlayer = AudioPlayer();
  final AudioPlayer _deathPlayer = AudioPlayer();

  late final Uint8List _eatWav;
  late final Uint8List _bonusWav;
  late final Uint8List _deathWav;

  SoundManager() {
    // Short high-pitched blip for eating food.
    _eatWav = _generateTone(frequency: 880, durationMs: 60, volume: 0.3);
    // Rising two-tone for bonus pickup.
    _bonusWav = _generateTwoTone(
      freq1: 660,
      freq2: 990,
      durationMs: 120,
      volume: 0.3,
    );
    // Low descending buzz for death.
    _deathWav = _generateTwoTone(
      freq1: 440,
      freq2: 110,
      durationMs: 300,
      volume: 0.4,
    );
  }

  void playEat() => _play(_eatPlayer, _eatWav);
  void playBonus() => _play(_bonusPlayer, _bonusWav);
  void playDeath() => _play(_deathPlayer, _deathWav);

  void _play(AudioPlayer player, Uint8List wav) {
    player.play(BytesSource(wav));
  }

  void dispose() {
    _eatPlayer.dispose();
    _bonusPlayer.dispose();
    _deathPlayer.dispose();
  }

  /// Generate a mono 16-bit 44100 Hz WAV with a single sine tone.
  static Uint8List _generateTone({
    required double frequency,
    required int durationMs,
    required double volume,
  }) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    final maxAmp = (32767 * volume).round();

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Apply a quick fade-out envelope to avoid clicks.
      final envelope = 1.0 - (i / numSamples);
      samples[i] =
          (math.sin(2 * math.pi * frequency * t) * maxAmp * envelope).round();
    }

    return _wavFromSamples(samples, sampleRate);
  }

  /// Generate a tone that sweeps from [freq1] to [freq2].
  static Uint8List _generateTwoTone({
    required double freq1,
    required double freq2,
    required int durationMs,
    required double volume,
  }) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    final maxAmp = (32767 * volume).round();

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = i / numSamples;
      final freq = freq1 + (freq2 - freq1) * progress;
      final envelope = 1.0 - progress;
      samples[i] =
          (math.sin(2 * math.pi * freq * t) * maxAmp * envelope).round();
    }

    return _wavFromSamples(samples, sampleRate);
  }

  /// Wraps raw PCM samples in a WAV file header.
  static Uint8List _wavFromSamples(Int16List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;
    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt sub-chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // sub-chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample

    // data sub-chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, samples.buffer.asUint8List());
    return result;
  }
}
