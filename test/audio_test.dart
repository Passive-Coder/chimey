import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/audio.dart';

Uint8List tone(double hz, double amplitude) {
  final bytes = ByteData(2048);
  for (var i = 0; i < 1024; i++) {
    bytes.setInt16(
      i * 2,
      (math.sin(2 * math.pi * hz * i / 16000) * amplitude * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

void main() {
  test('silence produces finite zero energy and no frequency', () {
    final frame = SignalAnalyzer().add(Uint8List(2048))!;
    expect(frame.level, 0);
    expect(frame.frequency, 0);
    expect(frame.dbfs, -96);
  });
  test('a 1kHz PCM tone drives measured frequency and dBFS', () {
    final frame = SignalAnalyzer().add(tone(1000, .5))!;
    expect(frame.frequency, closeTo(1000, 16));
    expect(frame.dbfs, closeTo(-9.03, .1));
    expect(frame.level, greaterThan(.7));
    expect(frame.bands.length, 32);
    expect(frame.bands.every((v) => v >= 0 && v <= 1), isTrue);
  });
  test('louder PCM produces more visual energy', () {
    final quiet = SignalAnalyzer().add(tone(250, .01))!;
    final loud = SignalAnalyzer().add(tone(250, .8))!;
    expect(loud.level, greaterThan(quiet.level));
    expect(loud.dbfs, greaterThan(quiet.dbfs));
  });
  test('split samples are reassembled across odd byte boundaries', () {
    final bytes = tone(2000, .4);
    final analyzer = SignalAnalyzer();
    expect(analyzer.add(Uint8List.sublistView(bytes, 0, 333)), isNull);
    final frame = analyzer.add(Uint8List.sublistView(bytes, 333))!;
    expect(frame.frequency, closeTo(2000, 16));
  });
}
