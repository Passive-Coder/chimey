import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chimey/audio.dart';
import 'package:chimey/sounds/assist.dart';
import 'package:chimey/sounds/online.dart';
import 'package:chimey/sounds/runtime.dart';
import 'audio_session_test.dart' show TestDevice;

class CountingAudioSession extends AudioSession {
  CountingAudioSession(TestDevice device) : super(deviceFactory: () => device);
  int snapshots = 0;
  @override
  Uint8List recentWav() {
    snapshots++;
    return super.recentWav();
  }
}

class DelayedStopDevice extends TestDevice {
  Completer<void>? release;
  @override
  Future<void> stop() async {
    await release?.future;
    await super.stop();
  }
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  testWidgets('external microphone stop restores the start control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final device = DelayedStopDevice();
    final audio = AudioSession(deviceFactory: () => device);
    final runtime = SoundRuntime();
    await tester.runAsync(audio.start);
    await tester.pumpWidget(
      MaterialApp(
        home: SoundAssist(runtime: runtime, audio: audio),
      ),
    );
    Future<void>? stopping;
    await tester.runAsync(() async {
      device.release = Completer<void>();
      stopping = audio.stop();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    final start = find.widgetWithText(OutlinedButton, 'Start microphone');
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
    await tester.runAsync(() async {
      device.release!.complete();
      await stopping;
    });
    await tester.pump();
    expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      audio.dispose();
      await Future<void>.delayed(Duration.zero);
    });
    runtime.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  for (final stopBeforeApproval in [false, true]) {
    testWidgets(
      stopBeforeApproval
          ? 'foreground audio stopped during consent cannot be shared'
          : 'foreground audio sharing snapshots only after consent and never creates a rule',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final device = TestDevice();
        final audio = CountingAudioSession(device);
        final runtime = SoundRuntime();
        await runtime.store.load();
        await tester.runAsync(() async {
          await audio.start();
          device.stream.add(Uint8List(32000));
          await Future<void>.delayed(Duration.zero);
        });
        var requests = 0;
        final online = OnlineAssistance(
          client: MockClient((request) async {
            requests++;
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            final clip = base64Decode(payload['audio'] as String);
            expect(clip.length, 32044);
            expect(String.fromCharCodes(clip.sublist(0, 4)), 'RIFF');
            expect(payload['consent'], true);
            expect(payload.containsKey('description'), false);
            return http.Response(
              '{"kind":"explanation","confirmed":false,"text":"Possible repeating beep"}',
              200,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: SoundAssist(
              runtime: runtime,
              audio: audio,
              assistance: online,
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextField).at(0),
          'https://example.com/assist',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          'test-token-with-at-least-24-characters',
        );
        final analyze = find.text('Analyze recent audio online');
        await tester.ensureVisible(analyze);
        await tester.tap(analyze);
        await tester.pumpAndSettle();
        expect(find.textContaining('last eight seconds'), findsWidgets);
        expect(audio.snapshots, 0);
        expect(requests, 0);
        if (!stopBeforeApproval) {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(audio.snapshots, 0);
          await tester.tap(analyze);
          await tester.pumpAndSettle();
        } else {
          await tester.runAsync(audio.stop);
          await tester.pump();
        }
        await tester.tap(find.text('Share this time'));
        await tester.pumpAndSettle();
        expect(audio.snapshots, 1);
        expect(requests, stopBeforeApproval ? 0 : 1);
        if (stopBeforeApproval) {
          expect(find.textContaining('Start the microphone'), findsOneWidget);
        } else {
          expect(find.text('Possible repeating beep'), findsOneWidget);
          expect(
            find.text('POSSIBLE EXPLANATION · UNCONFIRMED'),
            findsOneWidget,
          );
        }
        expect(runtime.store.sounds, isEmpty);
        expect(runtime.store.events, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(audio.stop);
        await tester.runAsync(() async {
          audio.dispose();
          await Future<void>.delayed(Duration.zero);
        });
        runtime.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
