import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chimey/sounds/assist.dart';
import 'package:chimey/main.dart';
import 'package:chimey/sounds/runtime.dart';
import 'package:chimey/sounds/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      NativeRuntime.channel,
      (call) async => call.method == 'modelStatus'
          ? {'state': 'unloaded', 'installed': false}
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('chimey/runtime/events'),
      (_) async => null,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NativeRuntime.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('chimey/runtime/events'),
      null,
    );
  });
  testWidgets(
    'an unfamiliar sound can be labeled without a model and cannot bypass calibration',
    (tester) async {
      final runtime = SoundRuntime();
      await runtime.store.load();
      runtime.state = 'listening';
      await tester.pumpWidget(MaterialApp(home: SoundAssist(runtime: runtime)));
      await tester.pump();
      await tester.tap(find.text('Label and teach this sound'));
      await tester.pumpAndSettle();
      expect(find.text('Teach a personal sound'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'My unfamiliar tone');
      await tester.tap(find.text('Validate & save'));
      await tester.pump();
      expect(
        find.textContaining('at least three separate examples'),
        findsOneWidget,
      );
      expect(runtime.store.sounds, isEmpty);
      await tester.pumpWidget(const SizedBox());
      runtime.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'microphone restart stays blocked after corrupt library initialization',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferenceStorage.key: 'unreadable data',
      });
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeRuntime.channel, (call) async {
            calls.add(call.method);
            return null;
          });
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Use microphone'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, contains('stop'));
      expect(calls, isNot(contains('start')));
      expect(find.textContaining('preserved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test(
    'corrupt primary storage stops listening without overwriting native profiles',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferenceStorage.key: 'unreadable data',
      });
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeRuntime.channel, (call) async {
            calls.add(call.method);
            return null;
          });
      final runtime = SoundRuntime();
      await runtime.initialize();
      expect(calls, ['stop']);
      expect(runtime.error, contains('preserved'));
      expect(
        (await SharedPreferences.getInstance()).getString(
          PreferenceStorage.key,
        ),
        'unreadable data',
      );
      runtime.dispose();
    },
  );
}
