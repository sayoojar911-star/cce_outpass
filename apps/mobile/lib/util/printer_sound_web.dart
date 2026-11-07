import 'dart:js_interop';

@JS('window.ccePrinterAudio.start')
external void _startAudio(JSNumber durationMs);

@JS('window.ccePrinterAudio.stop')
external void _stopAudio();

void playPrinterSoundPlatform(int durationMs) {
  try {
    _startAudio(durationMs.toJS);
  } catch (_) {}
}

void stopPrinterSoundPlatform() {
  try {
    _stopAudio();
  } catch (_) {}
}
