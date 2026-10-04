import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioFrame {
  const AudioFrame({
    this.dbfs = -96,
    this.level = 0,
    this.frequency = 0,
    this.bands = const [],
  });
  final double dbfs, level, frequency;
  final List<double> bands;
}

/// 16-bit little-endian mono PCM at 16kHz. 1024 samples = 64ms per FFT.
/// dBFS measures digital amplitude, not calibrated environmental dB SPL.
class SignalAnalyzer {
  final _samples = Float64List(1024);
  int _count = 0;
  int? _lowByte;
  AudioFrame? add(Uint8List bytes) {
    AudioFrame? latest;
    for (final byte in bytes) {
      if (_lowByte == null) {
        _lowByte = byte;
        continue;
      }
      var value = _lowByte! | (byte << 8);
      if (value >= 32768) {
        value -= 65536;
      }
      _lowByte = null;
      _samples[_count++] = value / 32768;
      if (_count == 1024) {
        latest = _analyze();
        _count = 0;
      }
    }
    return latest;
  }

  AudioFrame _analyze() {
    const n = 1024;
    var energy = 0.0, mean = 0.0;
    for (final v in _samples) {
      energy += v * v;
      mean += v;
    }
    mean /= n;
    final rms = math.sqrt(energy / n);
    final dbfs = rms <= .0000158
        ? -96.0
        : (20 * math.log(rms) / math.ln10).clamp(-96.0, 0.0);
    final real = Float64List(n), imag = Float64List(n);
    for (var i = 0; i < n; i++) {
      real[i] =
          (_samples[i] - mean) *
          (.5 - .5 * math.cos(2 * math.pi * i / (n - 1)));
    }
    // Iterative radix-2 FFT: bounded memory and O(n log n).
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final temp = real[i];
        real[i] = real[j];
        real[j] = temp;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final angle = -2 * math.pi / len;
      final wr = math.cos(angle), wi = math.sin(angle);
      for (var i = 0; i < n; i += len) {
        var xr = 1.0, xi = 0.0;
        for (var j = 0; j < len ~/ 2; j++) {
          final a = i + j, b = a + len ~/ 2;
          final vr = real[b] * xr - imag[b] * xi,
              vi = real[b] * xi + imag[b] * xr;
          real[b] = real[a] - vr;
          imag[b] = imag[a] - vi;
          real[a] += vr;
          imag[a] += vi;
          final next = xr * wr - xi * wi;
          xi = xr * wi + xi * wr;
          xr = next;
        }
      }
    }
    final magnitudes = List.generate(
      n ~/ 2,
      (i) => math.sqrt(real[i] * real[i] + imag[i] * imag[i]) * 4 / n,
    );
    var peak = 0, peakValue = 0.0;
    for (var i = 2; i < magnitudes.length; i++) {
      if (magnitudes[i] > peakValue) {
        peak = i;
        peakValue = magnitudes[i];
      }
    }
    final bands = List.generate(32, (i) {
      final low = (math.pow(512, i / 32)).floor().clamp(1, 511);
      final high = (math.pow(512, (i + 1) / 32)).ceil().clamp(low + 1, 512);
      var value = 0.0;
      for (var bin = low; bin < high; bin++) {
        value = math.max(value, magnitudes[bin]);
      }
      return value <= .00001
          ? 0.0
          : ((20 * math.log(value) / math.ln10 + 70) / 70).clamp(0.0, 1.0);
    });
    return AudioFrame(
      dbfs: dbfs,
      level: ((dbfs + 60) / 60).clamp(0.0, 1.0),
      frequency: dbfs < -65 || peakValue < .0001 ? 0 : peak * 16000 / n,
      bands: bands,
    );
  }
}

abstract interface class CaptureDevice {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

class RecordCapture implements CaptureDevice {
  final _recorder = AudioRecorder();
  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ),
  );
  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Foreground session. Generation checks cancel starts that outlive navigation,
/// permission prompts, lifecycle changes, or widget disposal.
class AudioSession extends ChangeNotifier {
  AudioSession({CaptureDevice Function()? deviceFactory})
    : _factory = deviceFactory ?? RecordCapture.new;
  final CaptureDevice Function() _factory;
  CaptureDevice? _device;
  StreamSubscription<Uint8List>? _subscription;
  Future<void>? _pending;
  bool active = false, starting = false, stopping = false, _closed = false;
  int _generation = 0;
  String? error;
  AudioFrame frame = const AudioFrame();
  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  Future<void> start() {
    if (_closed || active || starting || stopping) {
      return Future.value();
    }
    starting = true;
    error = null;
    frame = const AudioFrame();
    final token = ++_generation;
    _notify();
    return _pending = _begin(token);
  }

  Future<void> _begin(int token) async {
    final device = _device ??= _factory();
    try {
      final allowed = await device.hasPermission();
      if (_closed || token != _generation) {
        return;
      }
      if (!allowed) {
        throw StateError('permission');
      }
      final stream = await device.start();
      if (_closed || token != _generation) {
        await device.stop();
        return;
      }
      active = true;
      starting = false;
      final analyzer = SignalAnalyzer();
      _subscription = stream.listen(
        (bytes) {
          if (!active || _closed) {
            return;
          }
          final next = analyzer.add(bytes);
          if (next != null) {
            frame = next;
            _notify();
          }
        },
        onError: (Object e) {
          error = 'Microphone interrupted. Try again or use the demo.';
          unawaited(stop());
        },
        onDone: () {
          if (active) {
            error = 'Microphone stopped. Tap Use microphone to reconnect.';
            unawaited(stop());
          }
        },
      );
    } catch (_) {
      if (token == _generation && !_closed) {
        error =
            'Microphone unavailable. Allow access in settings, or keep exploring the demo.';
        active = false;
      }
      try {
        await device.stop();
      } catch (_) {}
    } finally {
      if (token == _generation) {
        starting = false;
        _notify();
      }
    }
  }

  Future<void> stop() async {
    ++_generation;
    active = false;
    starting = false;
    stopping = true;
    frame = const AudioFrame();
    _notify();
    await _subscription?.cancel();
    _subscription = null;
    await _pending;
    try {
      await _device?.stop();
    } catch (_) {}
    stopping = false;
    _notify();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    await stop();
    await _device?.dispose();
  }
}
