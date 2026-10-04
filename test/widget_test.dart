import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/main.dart';

void main() {
  testWidgets('listening can pause and resume', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    expect(find.text('chimey'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause listening'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Listening paused.'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume listening'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your space sounds calm.'), findsOneWidget);
  });

  testWidgets('demo event produces a labeled response and activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Doorbell'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Someone’s at the door.'), findsOneWidget);
    expect(find.text('Demo response · no notification sent'), findsOneWidget);
    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Doorbell rang'), findsOneWidget);
  });

  testWidgets('phone layout supports teaching a session sound', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Sounds'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Teach a sound'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Coffee machine');
    await tester.tap(find.text('Save demo sound'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Coffee machine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
