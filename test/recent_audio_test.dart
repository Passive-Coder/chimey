import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/audio.dart';
import 'audio_session_test.dart' show TestDevice;

void main() {
  test(
    'recent WAV preserves split PCM samples and declares the real format',
    () {
      final audio = RecentPcmAudio();
      final pcm = Uint8List.fromList(List.generate(32000, (i) => i % 251));
      audio.add(Uint8List.sublistView(pcm, 0, 101));
      audio.add(Uint8List.sublistView(pcm, 101));
      audio.add(Uint8List.fromList([99]));
      final wav = audio.wav();
      final header = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint32(28, Endian.little), 32000);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), 32000);
      expect(wav.sublist(44), pcm);
    },
  );

  test(
    'only the most recent eight seconds survive and snapshots are independent',
    () {
      final audio = RecentPcmAudio();
      final pcm = Uint8List.fromList(List.generate(32000 * 9, (i) => i % 251));
      audio.add(pcm);
      final wav = audio.wav();
      expect(wav.length, 44 + 32000 * 8);
      expect(wav.sublist(44), pcm.sublist(32000));
      audio.clear();
      expect(audio.wav, throwsStateError);
      expect(wav.sublist(44), pcm.sublist(32000));
    },
  );

  test(
    'microphone stop, interruption and restart cannot expose stale audio',
    () async {
      final device = TestDevice();
      final session = AudioSession(deviceFactory: () => device);
      await session.start();
      device.stream.add(Uint8List(32000));
      await Future<void>.delayed(Duration.zero);
      expect(session.recentWav().length, 32044);
      await session.stop();
      expect(session.recentWav, throwsStateError);
      await session.start();
      expect(session.recentWav, throwsStateError);
      device.stream.add(Uint8List(32000));
      await Future<void>.delayed(Duration.zero);
      device.stream.addError(StateError('disconnected'));
      await Future<void>.delayed(Duration.zero);
      expect(session.recentWav, throwsStateError);
      session.dispose();
    },
  );
}
