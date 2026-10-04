import 'dart:math' as math;
import 'models.dart';

class RecognitionEngine {
  RecognitionResult classify(
    List<double> features,
    List<PersonalSound> sounds, {
    String? category,
    double categoryScore = 0,
    String featureModel = 'yamnet',
  }) {
    if (!validVector(features)) {
      return _unknown('Insufficient acoustic evidence');
    }
    final matches = <({PersonalSound sound, double score})>[];
    for (final sound in sounds) {
      if (!sound.enabled ||
          !sound.validated ||
          sound.featureModel != featureModel ||
          sound.examples.isEmpty) {
        continue;
      }
      final score = sound.examples
          .map((v) => cosine(features, v))
          .reduce(math.max);
      matches.add((sound: sound, score: score));
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    if (matches.length > 1 && matches.first.score - matches[1].score < .05) {
      return _unknown('Similar personal sounds; record more examples');
    }
    if (matches.isNotEmpty &&
        matches.first.score >= matches.first.sound.threshold) {
      return RecognitionResult(
        kind: RecognitionKind.personal,
        label: matches.first.sound.name,
        sound: matches.first.sound,
        score: matches.first.score,
        reason: 'Matched a validated personal profile',
      );
    }
    if (category != null &&
        categoryScore.isFinite &&
        categoryScore >= .6 &&
        categoryScore <= 1) {
      return RecognitionResult(
        kind: RecognitionKind.category,
        label: category,
        score: categoryScore,
        reason: 'Broad acoustic category, not appliance identity',
      );
    }
    return _unknown('Unknown or mixed sound');
  }

  RecognitionResult _unknown(String reason) => RecognitionResult(
    kind: RecognitionKind.unknown,
    label: 'Unfamiliar sound',
    reason: reason,
  );
}

class EnrollmentCalibration {
  const EnrollmentCalibration(this.validated, this.threshold, this.reason);
  final bool validated;
  final double threshold;
  final String reason;
  static EnrollmentCalibration validate(
    List<List<double>> examples,
    List<List<double>> background,
  ) {
    if (examples.length < 3 || background.isEmpty) {
      return const EnrollmentCalibration(
        false,
        .95,
        'Record at least three separate examples and a quiet-room reference',
      );
    }
    final dimension = examples.first.length;
    if ([
      ...examples,
      ...background,
    ].any((v) => !validVector(v) || v.length != dimension)) {
      return const EnrollmentCalibration(
        false,
        .95,
        'Acoustic features are invalid or incompatible',
      );
    }
    // Leave-one-out: each example must match an independently recorded example.
    var positiveFloor = 1.0;
    for (var i = 0; i < examples.length; i++) {
      var closest = -1.0;
      for (var j = 0; j < examples.length; j++) {
        if (i != j) {
          closest = math.max(closest, cosine(examples[i], examples[j]));
        }
      }
      positiveFloor = math.min(positiveFloor, closest);
    }
    var negativeCeiling = -1.0;
    for (final noise in background) {
      for (final example in examples) {
        negativeCeiling = math.max(negativeCeiling, cosine(noise, example));
      }
    }
    if (positiveFloor < .8 || positiveFloor - negativeCeiling < .08) {
      return const EnrollmentCalibration(
        false,
        .95,
        'Sound is inconsistent or too similar to room noise',
      );
    }
    final threshold = math.max(.8, (positiveFloor + negativeCeiling) / 2);
    return EnrollmentCalibration(
      true,
      threshold,
      'Validated against repeated examples and room noise',
    );
  }
}

class RuleGate {
  RuleGate({Map<String, int>? lastActions})
    : lastActions = Map.of(lastActions ?? {});
  final Map<String, int> lastActions;
  bool allow(String id, SoundRule rule, DateTime now) {
    final last = lastActions[id];
    final time = now.millisecondsSinceEpoch;
    // Clock rollback must not immediately retrigger a previously delivered rule.
    if (last != null && time - last < rule.cooldownSeconds * 1000) return false;
    lastActions[id] = time;
    return true;
  }
}
