import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chimey/sounds/models.dart';
import 'package:chimey/sounds/runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'denied notifications never prevent disabling an existing rule',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(NativeRuntime.channel, (call) async {
        calls.add(call.method);
        return call.method == 'notifications' ? false : null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(NativeRuntime.channel, null),
      );
      final runtime = SoundRuntime();
      await runtime.store.load();
      final sound = PersonalSound(
        id: 'door',
        name: 'Door',
        examples: const [
          [1, 0],
          [1, 0],
          [1, 0],
        ],
        validated: true,
        rule: const SoundRule(notification: true, vibration: true),
      );
      await runtime.store.upsert(sound);
      await runtime.save(sound.copyWith(enabled: false));
      expect(runtime.store.sounds.single.enabled, isFalse);
      expect(calls, ['profiles']);
      await expectLater(runtime.save(sound), throwsStateError);
      expect(runtime.store.sounds.single.enabled, isFalse);
      runtime.dispose();
    },
  );
}
