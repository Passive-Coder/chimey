import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/sounds/models.dart';
import 'package:chimey/sounds/recognition.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/yamnet-synthetic.json').readAsStringSync())
          as Map<String, dynamic>;
  List<double> features(String name) =>
      ((fixture['frames'][name]['features']) as List)
          .map((v) => (v as num).toDouble())
          .toList();
  final examples = ['example1', 'example2', 'example3'].map(features).toList();
  final calibration = EnrollmentCalibration.validate(examples, [
    features('roomNoise'),
  ]);
  PersonalSound profile(String id) => PersonalSound(
    id: id,
    name: 'Synthetic 1 kHz tone',
    examples: examples,
    threshold: calibration.threshold,
    validated: calibration.validated,
    featureModel: fixture['featureModel'] as String,
    rule: const SoundRule(notification: false, vibration: true),
  );
  RecognitionResult classify(String frame, List<PersonalSound> profiles) =>
      RecognitionEngine().classify(
        features(frame),
        profiles,
        featureModel: fixture['featureModel'] as String,
      );
  test('actual YAMNet examples enroll and recognize a held-out repetition', () {
    expect(fixture['synthetic'], isTrue);
    expect(examples.first.length, 1024);
    expect(calibration.validated, isTrue);
    final result = classify('heldOut', [profile('tone')]);
    expect(result.kind, RecognitionKind.personal);
    expect(result.canExecute, isTrue);
  });
  test(
    'actual silence, noise and a different tone cannot trigger this profile',
    () {
      for (final name in ['silence', 'roomNoise', 'differentTone']) {
        final result = classify(name, [profile('tone')]);
        expect(result.canExecute, isFalse, reason: name);
        expect(result.kind, RecognitionKind.unknown, reason: name);
      }
    },
  );
  test(
    'actual model features still abstain when two personal profiles collide',
    () {
      expect(
        classify('heldOut', [profile('a'), profile('b')]).canExecute,
        isFalse,
      );
      expect(
        classify('heldOut', [profile('a').copyWith(enabled: false)]).canExecute,
        isFalse,
      );
    },
  );
}
