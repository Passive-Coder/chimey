import 'dart:math' as math;

enum RecognitionKind { personal, category, explanation, unknown }

class SoundRule {
  const SoundRule({
    this.notification = true,
    this.vibration = false,
    this.pattern = const [0, 180, 120, 180],
    this.ledEndpoint,
    this.cooldownSeconds = 30,
  });
  final bool notification, vibration;
  final List<int> pattern;
  final String? ledEndpoint;
  final int cooldownSeconds;
  Map<String, Object?> toJson() => {
    'notification': notification,
    'vibration': vibration,
    'pattern': pattern,
    'ledEndpoint': ledEndpoint,
    'cooldownSeconds': cooldownSeconds,
  };
  factory SoundRule.fromJson(Map<String, dynamic> json) {
    final pattern = (json['pattern'] as List).map((v) => v as int).toList();
    if (pattern.isEmpty ||
        pattern.length > 20 ||
        pattern.any((v) => v < 0 || v > 5000) ||
        pattern.fold(0, (a, b) => a + b) > 10000) {
      throw const FormatException('Invalid vibration pattern');
    }
    final cooldown = json['cooldownSeconds'] as int;
    if (cooldown < 1 || cooldown > 86400) {
      throw const FormatException('Invalid cooldown');
    }
    final endpoint = json['ledEndpoint'] as String?;
    if (endpoint != null) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid LED endpoint');
      }
    }
    return SoundRule(
      notification: json['notification'] as bool,
      vibration: json['vibration'] as bool,
      pattern: List.unmodifiable(pattern),
      cooldownSeconds: cooldown,
      ledEndpoint: endpoint,
    );
  }
}

class PersonalSound {
  PersonalSound({
    required this.id,
    required this.name,
    required List<List<double>> examples,
    this.description = '',
    this.threshold = .95,
    this.validated = false,
    this.enabled = true,
    this.rule = const SoundRule(),
    this.featureModel = 'yamnet',
  }) : examples = List.unmodifiable(
         examples.map((v) => List<double>.unmodifiable(v)),
       );
  final String id, name, description, featureModel;
  final List<List<double>> examples;
  final double threshold;
  final bool validated, enabled;
  final SoundRule rule;
  PersonalSound copyWith({
    String? name,
    String? description,
    List<List<double>>? examples,
    double? threshold,
    bool? validated,
    bool? enabled,
    SoundRule? rule,
  }) => PersonalSound(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    examples: examples ?? this.examples,
    threshold: threshold ?? this.threshold,
    validated: validated ?? this.validated,
    enabled: enabled ?? this.enabled,
    rule: rule ?? this.rule,
    featureModel: featureModel,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'examples': examples,
    'threshold': threshold,
    'validated': validated,
    'enabled': enabled,
    'rule': rule.toJson(),
    'featureModel': featureModel,
  };
  factory PersonalSound.fromJson(Map<String, dynamic> json) {
    final examples = (json['examples'] as List)
        .map((v) => (v as List).map((n) => (n as num).toDouble()).toList())
        .toList();
    final id = json['id'] as String, name = json['name'] as String;
    final threshold = (json['threshold'] as num).toDouble();
    if (id.isEmpty ||
        name.trim().isEmpty ||
        name.length > 80 ||
        !threshold.isFinite ||
        threshold <= 0 ||
        threshold > 1 ||
        examples.length > 32 ||
        examples.any((v) => !validVector(v)) ||
        (examples.isNotEmpty &&
            examples.any((v) => v.length != examples.first.length))) {
      throw const FormatException('Invalid sound profile');
    }
    final validated = json['validated'] as bool;
    if (validated && examples.length < 3) {
      throw const FormatException('Validated sound needs repeated examples');
    }
    return PersonalSound(
      id: id,
      name: name,
      description: json['description'] as String,
      examples: examples,
      threshold: threshold,
      validated: validated,
      enabled: json['enabled'] as bool,
      rule: SoundRule.fromJson(json['rule'] as Map<String, dynamic>),
      featureModel: json['featureModel'] as String,
    );
  }
}

bool validVector(List<double> vector) =>
    vector.isNotEmpty &&
    vector.length <= 4096 &&
    vector.every((v) => v.isFinite) &&
    vector.any((v) => v != 0);

double cosine(List<double> a, List<double> b) {
  if (a.length != b.length || !validVector(a) || !validVector(b)) return -1;
  var dot = 0.0, aa = 0.0, bb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  final value = dot / math.sqrt(aa * bb);
  return value.isFinite ? value.clamp(-1.0, 1.0) : -1;
}

class RecognitionResult {
  const RecognitionResult({
    required this.kind,
    required this.label,
    this.score = 0,
    this.sound,
    this.reason = '',
  });
  factory RecognitionResult.explanation(String label) => RecognitionResult(
    kind: RecognitionKind.explanation,
    label: label,
    reason: 'Unconfirmed hypothesis',
  );
  final RecognitionKind kind;
  final String label, reason;
  final double score;
  final PersonalSound? sound;
  bool get canExecute =>
      kind == RecognitionKind.personal &&
      sound != null &&
      sound!.validated &&
      sound!.enabled &&
      score.isFinite &&
      score >= sound!.threshold;
}

class SoundEvent {
  const SoundEvent({
    required this.id,
    required this.label,
    required this.kind,
    required this.time,
    this.score = 0,
    this.soundId,
    this.delivery = 'No action',
    this.correction,
  });
  final String id, label, delivery;
  final RecognitionKind kind;
  final DateTime time;
  final double score;
  final String? soundId, correction;
  SoundEvent corrected(String text) => SoundEvent(
    id: id,
    label: label,
    kind: kind,
    time: time,
    score: score,
    soundId: soundId,
    delivery: delivery,
    correction: text,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'time': time.toUtc().toIso8601String(),
    'score': score,
    'soundId': soundId,
    'delivery': delivery,
    'correction': correction,
  };
  factory SoundEvent.fromJson(Map<String, dynamic> json) => SoundEvent(
    id: json['id'] as String,
    label: json['label'] as String,
    kind: RecognitionKind.values.byName(json['kind'] as String),
    time: DateTime.parse(json['time'] as String),
    score: (json['score'] as num).toDouble(),
    soundId: json['soundId'] as String?,
    delivery: json['delivery'] as String,
    correction: json['correction'] as String?,
  );
}
