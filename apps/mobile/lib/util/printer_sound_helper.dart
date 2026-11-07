import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'printer_sound_stub.dart'
    if (dart.library.js_interop) 'printer_sound_web.dart' as impl;

/// Helper for thermal receipt printer sound effects and user toggle.
class PrinterSoundHelper {
  PrinterSoundHelper._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'cce_printer_sound_enabled';

  static bool _soundEnabledCache = true;
  static bool _hasLoaded = false;
  static bool _isPlaying = false;

  /// Check whether printer audio is enabled (persisted, default ON).
  static Future<bool> isSoundEnabled() async {
    if (_hasLoaded) return _soundEnabledCache;
    try {
      final val = await _storage.read(key: _storageKey);
      if (val != null) {
        _soundEnabledCache = val.toLowerCase() != 'false';
      } else {
        _soundEnabledCache = true;
      }
    } catch (_) {
      _soundEnabledCache = true;
    }
    _hasLoaded = true;
    return _soundEnabledCache;
  }

  /// Synchronous cache getter for UI builds.
  static bool get isSoundEnabledSync => _soundEnabledCache;
  static bool get soundEnabled => _soundEnabledCache;

  /// Toggle or update the sound preference.
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabledCache = enabled;
    _hasLoaded = true;
    if (!enabled && _isPlaying) {
      stopPrinterSound();
    }
    try {
      await _storage.write(key: _storageKey, value: enabled ? 'true' : 'false');
    } catch (_) {}
  }

  /// Start playing the continuous thermal printer sound for the given duration.
  static void startPrinterSound({required Duration duration, bool? enabled}) {
    final allowSound = enabled ?? _soundEnabledCache;
    if (!allowSound) return;

    _isPlaying = true;

    // Trigger platform Web Audio
    if (kIsWeb) {
      impl.playPrinterSoundPlatform(duration.inMilliseconds);
    } else {
      // Native Android / iOS haptic feedback sequence
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  /// Immediately stop any ongoing printer sound (on skip, unmount, or cancel).
  static void stopPrinterSound() {
    if (!_isPlaying && !kIsWeb) return;
    _isPlaying = false;

    if (kIsWeb) {
      impl.stopPrinterSoundPlatform();
    }
  }
}
