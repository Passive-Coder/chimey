import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/sounds/runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reattached capture ignores idle snapshots but ends on a genuine service stop',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('chimey/runtime'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('chimey/runtime/events'),
        (_) async => null,
      );
      Future<void> emit(Map<String, Object?> e) async {
        await messenger.handlePlatformMessage(
          'chimey/runtime/events',
          const StandardMethodCodec().encodeSuccessEnvelope(e),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
      }

      final capture = NativeCapture();
      final stream = await capture.start();
      final done = Completer<void>();
      var chunks = 0;
      stream.listen((_) {
        chunks++;
      }, onDone: done.complete);
      await emit({'type': 'status', 'state': 'stopped', 'snapshot': true});
      await emit({
        'type': 'pcm',
        'bytes': Uint8List.fromList([0, 1]),
      });
      expect(chunks, 1);
      expect(done.isCompleted, isFalse);
      // Existing service emits PCM only; no new starting/listening status is sent.
      await emit({'type': 'status', 'state': 'stopped'});
      await done.future.timeout(const Duration(milliseconds: 200));
      await capture.dispose();
    },
  );
}
