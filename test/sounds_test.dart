import 'package:flutter_test/flutter_test.dart';
import 'package:chimey/sounds/models.dart';
import 'package:chimey/sounds/recognition.dart';
import 'package:chimey/sounds/store.dart';

class MemoryStorage implements SoundStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String json) async {
    value = json;
  }
}

PersonalSound profile(
  String id,
  List<double> vector, {
  bool enabled = true,
  bool validated = true,
}) => PersonalSound(
  id: id,
  name: id,
  examples: [vector, vector, vector],
  threshold: .9,
  validated: validated,
  enabled: enabled,
  rule: const SoundRule(),
);
void main() {
  test(
    'profiles and distinct vibration rules survive a store restart',
    () async {
      final disk = MemoryStorage();
      final first = SoundStore(disk);
      await first.load();
      await first.upsert(
        profile('washer', [1, 0, 0]).copyWith(
          rule: const SoundRule(vibration: true, pattern: [0, 100, 80, 300]),
        ),
      );
      final restarted = SoundStore(disk);
      await restarted.load();
      expect(restarted.sounds.single.name, 'washer');
      expect(restarted.sounds.single.rule.pattern, [0, 100, 80, 300]);
      await restarted.upsert(restarted.sounds.single.copyWith(enabled: false));
      final again = SoundStore(disk);
      await again.load();
      expect(again.sounds.single.enabled, isFalse);
    },
  );
  test('unvalidated personal vectors never authorize actions', () {
    final result = RecognitionEngine().classify(
      [1, 0],
      [
        profile('door', [1, 0], validated: false),
      ],
    );
    expect(result.kind, RecognitionKind.unknown);
    expect(result.canExecute, isFalse);
  });
  test('two indistinguishable appliance sounds abstain', () {
    final result = RecognitionEngine().classify(
      [1, 0],
      [
        profile('washer', [1, 0]),
        profile('oven', [1, 0]),
      ],
    );
    expect(result.kind, RecognitionKind.unknown);
    expect(result.canExecute, isFalse);
  });
  test('validated matching profiles can act but disabled profiles cannot', () {
    final engine = RecognitionEngine();
    expect(
      engine
          .classify(
            [1, 0],
            [
              profile('door', [1, 0]),
            ],
          )
          .canExecute,
      isTrue,
    );
    expect(
      engine
          .classify(
            [1, 0],
            [
              profile('door', [1, 0], enabled: false),
            ],
          )
          .canExecute,
      isFalse,
    );
  });
  test('categories and hypotheses do not authorize appliance rules', () {
    final result = RecognitionEngine().classify(
      [0, 1],
      [],
      category: 'Beep',
      categoryScore: .9,
    );
    expect(result.kind, RecognitionKind.category);
    expect(result.canExecute, isFalse);
    expect(
      RecognitionResult.explanation('Possibly an oven timer').canExecute,
      isFalse,
    );
  });
  test('invalid and mismatched embeddings cannot match', () {
    final engine = RecognitionEngine();
    for (final vector in <List<double>>[
      [],
      [0, 0],
      [double.nan, 1],
      [double.infinity, 0],
      [1, 0, 0],
    ]) {
      expect(
        engine.classify(vector, [
          profile('door', [1, 0]),
        ]).canExecute,
        isFalse,
      );
    }
  });
  test('enrollment needs repeated examples and separation from room noise', () {
    final insufficient = EnrollmentCalibration.validate(
      [
        [1, 0],
        [1, .01],
      ],
      [
        [0, 1],
      ],
    );
    expect(insufficient.validated, isFalse);
    final distinct = EnrollmentCalibration.validate(
      [
        [1, 0],
        [1, .02],
        [1, -.01],
      ],
      [
        [0, 1],
      ],
    );
    expect(distinct.validated, isTrue);
    final noisy = EnrollmentCalibration.validate(
      [
        [1, 0],
        [1, .02],
        [1, -.01],
      ],
      [
        [1, 0],
      ],
    );
    expect(noisy.validated, isFalse);
  });
  test('rule cooldown survives controller restart', () {
    final gate = RuleGate(lastActions: {'door': 1000});
    final rule = const SoundRule(cooldownSeconds: 30);
    expect(
      gate.allow('door', rule, DateTime.fromMillisecondsSinceEpoch(2000)),
      isFalse,
    );
    expect(
      gate.allow('door', rule, DateTime.fromMillisecondsSinceEpoch(32000)),
      isTrue,
    );
    expect(
      gate.allow('door', rule, DateTime.fromMillisecondsSinceEpoch(33000)),
      isFalse,
    );
  });
  test(
    'corrupt stored data is reported without overwriting the original',
    () async {
      final disk = MemoryStorage()..value = '{broken';
      final store = SoundStore(disk);
      await store.load();
      expect(store.error, isNotNull);
      expect(disk.value, '{broken');
      await expectLater(
        store.upsert(profile('door', [1, 0])),
        throwsStateError,
      );
    },
  );
}
