import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/audio.dart';

class TestDevice implements CaptureDevice {
  bool allowed = true;
  int starts = 0, stops = 0, disposals = 0;
  Completer<bool>? permission;
  Completer<Stream<Uint8List>>? connection;
  final stream = StreamController<Uint8List>.broadcast();
  @override
  Future<bool> hasPermission() async =>
      permission == null ? allowed : await permission!.future;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    return connection == null ? stream.stream : await connection!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await stream.close();
  }
}

void main() {
  test(
    'denied microphone permission remains inactive with recovery text',
    () async {
      final device = TestDevice()..allowed = false;
      final audio = AudioSession(deviceFactory: () => device);
      await audio.start();
      expect(audio.active, isFalse);
      expect(audio.starting, isFalse);
      expect(audio.error, contains('Microphone unavailable'));
      expect(device.starts, 0);
      audio.dispose();
    },
  );
  test('stopping while permission is pending prevents capture', () async {
    final device = TestDevice()..permission = Completer<bool>();
    final audio = AudioSession(deviceFactory: () => device);
    final start = audio.start();
    final stop = audio.stop();
    device.permission!.complete(true);
    await start;
    await stop;
    expect(device.starts, 0);
    expect(audio.active, isFalse);
    expect(audio.starting, isFalse);
    audio.dispose();
  });
  test('stopping an in-flight connection releases the microphone', () async {
    final device = TestDevice()..connection = Completer<Stream<Uint8List>>();
    final audio = AudioSession(deviceFactory: () => device);
    final start = audio.start();
    await Future<void>.delayed(Duration.zero);
    expect(device.starts, 1);
    final stop = audio.stop();
    device.connection!.complete(device.stream.stream);
    await start;
    await stop;
    expect(device.stops, greaterThanOrEqualTo(1));
    expect(audio.active, isFalse);
    audio.dispose();
  });
  test(
    'capture processes audio and stop clears meters and subscription',
    () async {
      final device = TestDevice();
      final audio = AudioSession(deviceFactory: () => device);
      await audio.start();
      device.stream.add(Uint8List(2048));
      await Future<void>.delayed(Duration.zero);
      expect(audio.active, isTrue);
      expect(audio.frame.bands.length, 32);
      await audio.stop();
      expect(audio.active, isFalse);
      expect(audio.frame.bands, isEmpty);
      device.stream.add(Uint8List(2048));
      await Future<void>.delayed(Duration.zero);
      expect(audio.frame.bands, isEmpty);
      audio.dispose();
    },
  );
}
