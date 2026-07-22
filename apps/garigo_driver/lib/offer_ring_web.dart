import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Timer? _timer;
String? _dataUri;

void startOfferRing() {
  stopOfferRing();
  _dataUri ??= _makeBeepDataUri();
  _play();
  _timer = Timer.periodic(const Duration(milliseconds: 850), (_) => _play());
}

void stopOfferRing() {
  _timer?.cancel();
  _timer = null;
}

void _play() {
  try {
    final a = web.HTMLAudioElement();
    a.src = _dataUri!;
    a.volume = 0.55;
    a.play();
  } catch (_) {}
}

/// Tiny WAV beep (880 Hz, ~0.2s) — no asset file needed.
String _makeBeepDataUri() {
  const sampleRate = 22050;
  const durationSec = 0.2;
  final n = (sampleRate * durationSec).round();
  final dataSize = n * 2;
  final bytes = BytesBuilder();
  void u32(int v) {
    bytes.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
  }

  void u16(int v) {
    bytes.add([v & 255, (v >> 8) & 255]);
  }

  bytes.add(ascii.encode('RIFF'));
  u32(36 + dataSize);
  bytes.add(ascii.encode('WAVEfmt '));
  u32(16);
  u16(1);
  u16(1);
  u32(sampleRate);
  u32(sampleRate * 2);
  u16(2);
  u16(16);
  bytes.add(ascii.encode('data'));
  u32(dataSize);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final env = (i < 400)
        ? i / 400
        : (i > n - 400)
            ? (n - i) / 400
            : 1.0;
    final sample =
        (math.sin(2 * math.pi * 880 * t) * 12000 * env).round().clamp(-32768, 32767);
    u16(sample < 0 ? sample + 65536 : sample);
  }
  return 'data:audio/wav;base64,${base64Encode(bytes.toBytes())}';
}
