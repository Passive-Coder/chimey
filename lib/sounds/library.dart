import 'package:flutter/material.dart';
import 'models.dart';
import 'recognition.dart';
import 'runtime.dart';

class SoundLibrary extends StatefulWidget {
  const SoundLibrary({super.key, required this.runtime});
  final SoundRuntime runtime;
  @override
  State<SoundLibrary> createState() => _SoundLibraryState();
}

class _SoundLibraryState extends State<SoundLibrary> {
  SoundRuntime get runtime => widget.runtime;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: runtime,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Your sound library')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Teach a sound, choose its response, and refine it over time.',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 16),
          Text(
            nativeRecognition
                ? 'Start the microphone on the listening screen first. Record the sound three times and record the room without that sound.'
                : 'Personal recognition currently requires Android 8 or later. You can still explore the animation and foreground microphone here.',
          ),
          if (runtime.error != null)
            Text(runtime.error!, style: const TextStyle(color: Colors.amber)),
          if (runtime.store.error != null)
            Text(
              runtime.store.error!,
              style: const TextStyle(color: Colors.amber),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                nativeRecognition &&
                    runtime.state == 'listening' &&
                    runtime.store.loaded &&
                    runtime.store.error == null
                ? () => enroll()
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Record a personal sound'),
          ),
          const SizedBox(height: 20),
          for (final sound in runtime.store.sounds)
            Card(
              child: ListTile(
                title: Text(sound.name),
                subtitle: Text(
                  '${sound.validated ? 'Calibrated personal sound' : 'Needs enrollment'} · ${sound.examples.length} recordings',
                ),
                leading: Switch(
                  value: sound.enabled,
                  onChanged: (v) =>
                      perform(() => runtime.save(sound.copyWith(enabled: v))),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Configure ${sound.name}',
                  onPressed: () => configure(sound),
                ),
                onTap: () => configure(sound),
              ),
            ),
          const SizedBox(height: 24),
          const Text('Actual sound activity', style: TextStyle(fontSize: 20)),
          for (final event in runtime.store.events)
            ListTile(
              title: Text(event.label),
              subtitle: Text(
                '${event.kind.name} · ${event.delivery}\n${event.time.toLocal()}${event.correction == null ? '' : '\nCorrection: ${event.correction}'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: 'Correct this recognition',
                onPressed: () => correct(event),
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> perform(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Future<void> enroll({PersonalSound? existing}) async {
    final name = TextEditingController(text: existing?.name);
    final positive = <List<double>>[], background = <List<double>>[];
    var lastSequence = -1;
    String message =
        'Play your sound, then capture an example. Capture different repetitions, not the same moment.';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            existing == null
                ? 'Teach a personal sound'
                : 'Re-enroll ${existing.name}',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Sound name'),
                  ),
                  Text(message),
                  const SizedBox(height: 16),
                  Text(
                    '${positive.length}/3 sound examples · ${background.length}/1 room recording',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => update(() {
                          if (runtime.state != 'listening' ||
                              runtime.features == null ||
                              runtime.featureSequence - lastSequence < 3) {
                            message = 'Wait for a fresh microphone recording.';
                            return;
                          }
                          if (runtime.rms < .003) {
                            message =
                                'The recording is too quiet. Play the sound again.';
                            return;
                          }
                          if (positive.length < 3) {
                            positive.add(List.of(runtime.features!));
                            lastSequence = runtime.featureSequence;
                            message =
                                'Example captured. Play the next repetition.';
                          }
                        }),
                        child: const Text('Capture sound'),
                      ),
                      OutlinedButton(
                        onPressed: () => update(() {
                          if (runtime.state != 'listening' ||
                              runtime.features == null ||
                              runtime.featureSequence - lastSequence < 3) {
                            message = 'Wait for a fresh microphone recording.';
                            return;
                          }
                          background
                            ..clear()
                            ..add(List.of(runtime.features!));
                          lastSequence = runtime.featureSequence;
                          message =
                              'Room recording captured. Validate when ready.';
                        }),
                        child: const Text('Capture room'),
                      ),
                      TextButton(
                        onPressed: () => update(() {
                          positive.clear();
                          background.clear();
                          message = 'Start again.';
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  update(() => message = 'Give this sound a name.');
                  return;
                }
                final calibration = EnrollmentCalibration.validate(
                  positive,
                  background,
                );
                if (!calibration.validated) {
                  update(() => message = calibration.reason);
                  return;
                }
                final profile = PersonalSound(
                  id:
                      existing?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name.text.trim(),
                  examples: positive,
                  threshold: calibration.threshold,
                  validated: true,
                  rule: existing?.rule ?? const SoundRule(),
                  featureModel: 'yamnet-embedding-v1',
                );
                try {
                  await runtime.save(profile);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  update(() => message = 'Save failed: $e');
                }
              },
              child: const Text('Validate & save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (mounted) setState(() {});
  }

  Future<void> configure(PersonalSound sound) async {
    var notification = sound.rule.notification,
        vibration = sound.rule.vibration;
    var pattern = sound.rule.pattern;
    final endpoint = TextEditingController(text: sound.rule.ledEndpoint);
    var message = '';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(sound.name),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Notification'),
                    value: notification,
                    onChanged: (v) => update(() => notification = v),
                  ),
                  SwitchListTile(
                    title: const Text('Vibration'),
                    value: vibration,
                    onChanged: (v) => update(() => vibration = v),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: pattern.length == 2
                        ? 1
                        : pattern.length == 6
                        ? 3
                        : 2,
                    decoration: const InputDecoration(
                      labelText: 'Vibration pattern',
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('One long pulse')),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Two short pulses'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('Three quick pulses'),
                      ),
                    ],
                    onChanged: (v) => pattern = switch (v) {
                      1 => [0, 600],
                      3 => [0, 100, 100, 100, 100, 100],
                      _ => [0, 180, 120, 180],
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: endpoint,
                    decoration: const InputDecoration(
                      labelText: 'LED HTTPS endpoint (optional)',
                      helperText: 'Receives a JSON POST for a personal match',
                    ),
                  ),
                  if (message.isNotEmpty) Text(message),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      enroll(existing: sound);
                    },
                    child: const Text('Record new examples'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await perform(() => runtime.remove(sound.id));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Delete sound'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final rule = SoundRule(
                    notification: notification,
                    vibration: vibration,
                    pattern: pattern,
                    ledEndpoint: endpoint.text.trim().isEmpty
                        ? null
                        : endpoint.text.trim(),
                    cooldownSeconds: sound.rule.cooldownSeconds,
                  );
                  SoundRule.fromJson(rule.toJson());
                  await runtime.save(sound.copyWith(rule: rule));
                  if (notification && nativeRecognition) {
                    await NativeRuntime.channel.invokeMethod('notifications');
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  update(() => message = 'Could not save: $e');
                }
              },
              child: const Text('Save response'),
            ),
          ],
        ),
      ),
    );
    endpoint.dispose();
    if (mounted) setState(() {});
  }

  Future<void> correct(SoundEvent event) async {
    final text = TextEditingController();
    final correction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What did you hear?'),
        content: TextField(controller: text, maxLength: 200),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
    text.dispose();
    if (correction != null && correction.isNotEmpty) {
      await perform(() => runtime.store.correct(event.id, correction));
    }
  }
}
