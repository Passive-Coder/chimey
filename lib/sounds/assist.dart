import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../audio.dart';
import 'online.dart';
import 'models.dart';
import 'library.dart';
import 'runtime.dart';

class SoundAssist extends StatefulWidget {
  const SoundAssist({
    super.key,
    required this.runtime,
    this.audio,
    this.assistance,
  });
  final SoundRuntime runtime;
  final AudioSession? audio;
  final OnlineAssistance? assistance;
  @override
  State<SoundAssist> createState() => _SoundAssistState();
}

class _SoundAssistState extends State<SoundAssist> {
  Map<Object?, Object?> status = {};
  String? error, explanation;
  bool busy = false;
  late final online = widget.assistance ?? OnlineAssistance();
  final endpoint = TextEditingController();
  final token = TextEditingController();
  final description = TextEditingController();
  OnlineExplanation? onlineResult;
  StreamSubscription<Map<Object?, Object?>>? subscription;
  bool get listening => nativeRecognition
      ? widget.runtime.state == 'listening'
      : widget.audio?.active == true;
  (bool, bool, bool) get availability => (
    listening,
    widget.audio?.starting == true,
    widget.audio?.stopping == true,
  );
  late (bool, bool, bool) wasAvailability;
  void availabilityChanged() {
    if (mounted && availability != wasAvailability) {
      setState(() => wasAvailability = availability);
    }
  }

  @override
  void initState() {
    super.initState();
    wasAvailability = availability;
    widget.runtime.addListener(availabilityChanged);
    widget.audio?.addListener(availabilityChanged);
    if (nativeRecognition) {
      unawaited(refresh());
      subscription = NativeRuntime.events
          .where((e) => e['type'] == 'model')
          .listen((e) {
            if (mounted) setState(() => status = {...status, ...e});
          });
    }
  }

  Future<void> refresh() async {
    try {
      final next = await NativeRuntime.channel
          .invokeMapMethod<Object?, Object?>('modelStatus');
      if (mounted) setState(() => status = next ?? {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> run(String method) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await NativeRuntime.channel.invokeMethod<Object?>(method);
      if (method == 'explain' && mounted) {
        setState(() => explanation = result as String);
      }
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    widget.runtime.removeListener(availabilityChanged);
    widget.audio?.removeListener(availabilityChanged);
    unawaited(subscription?.cancel());
    online.close();
    endpoint.dispose();
    token.dispose();
    description.dispose();
    super.dispose();
  }

  Future<bool> openSource(String value) async {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        await launchUrl(uri);
  }

  Future<void> confirmAndTeach() async {
    final name = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What sound do you want to teach?'),
        content: TextField(
          controller: name,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Your confirmed interpretation',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(context, name.text.trim());
              }
            },
            child: const Text('Confirm & record examples'),
          ),
        ],
      ),
    );
    name.dispose();
    if (label == null || !mounted) return;
    try {
      await widget.runtime.store.addEvent(
        SoundEvent(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: 'Possible explanation',
          kind: RecognitionKind.explanation,
          time: DateTime.now(),
          correction: label,
        ),
      );
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SoundLibrary(runtime: widget.runtime, suggestedName: label),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> onlineRequest({required bool audio}) async {
    final uri = Uri.tryParse(endpoint.text.trim());
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(audio ? 'Share recent audio?' : 'Share this description?'),
        content: Text(
          audio
              ? 'Send the last eight seconds of microphone audio to ${uri?.host ?? "your service"} and Google Gemini for analysis? The recording can include speech and surrounding sounds. This is a possible explanation and cannot trigger a rule.'
              : 'Send your typed sound description to ${uri?.host ?? "your service"} and Google Gemini for internet research? No audio is included.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share this time'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Snapshot only after consent; the fixed bounded clip is sent once.
      final clip = audio
          ? nativeRecognition
                ? await NativeRuntime.channel.invokeMethod<Uint8List>('clip')
                : widget.audio?.recentWav()
          : null;
      if (audio && clip == null) {
        throw StateError('No recent recording is available');
      }
      final result = await online.request(
        endpoint: endpoint.text,
        token: token.text,
        wav: clip,
        description: audio ? null : description.text.trim(),
        consent: true,
      );
      if (mounted) setState(() => onlineResult = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Understand a sound')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'A possible explanation.\nYour confirmation matters.',
          style: TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          'While the microphone runs, the last eight seconds of audio stay in memory. On supported Android devices, the local audio model can explain them. Online analysis shares a clip only after your confirmation. Explanations never trigger a sound rule.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: nativeRecognition && !busy
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SoundLibrary(
                      runtime: widget.runtime,
                      beginEnrollment: true,
                    ),
                  ),
                )
              : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Label and teach this sound'),
        ),
        const Text(
          'You can give an unfamiliar sound your own label. A model explanation is optional; repeated acoustic examples still need validation.',
        ),
        const SizedBox(height: 24),
        Text(
          nativeRecognition
              ? 'Local audio model: ${status['state'] ?? 'checking'}'
              : 'Local audio model integration currently requires 64-bit Android.',
          style: const TextStyle(fontSize: 18),
        ),
        if (status['totalMemory'] is num)
          Text(
            'Device memory: ${((status['totalMemory'] as num) / 1073741824).toStringAsFixed(1)} GB. Model compatibility is checked when loading and analyzing audio.',
          ),
        const SizedBox(height: 12),
        const Text(
          'Import an audio-enabled Gemma 3n E2B .litertlm artifact obtained from its official distribution. Initialization is asynchronous; large models need sufficient memory and storage.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: nativeRecognition && !busy
                  ? () => run('pickModel')
                  : null,
              child: const Text('Import local model'),
            ),
            OutlinedButton(
              onPressed:
                  nativeRecognition && !busy && status['installed'] == true
                  ? () => run('loadModel')
                  : null,
              child: const Text('Load model'),
            ),
            TextButton(
              onPressed: nativeRecognition && !busy
                  ? () => run('unloadModel')
                  : null,
              child: const Text('Unload model'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!nativeRecognition && widget.audio != null) ...[
          OutlinedButton.icon(
            onPressed: busy || widget.audio!.starting || widget.audio!.stopping
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      if (widget.audio!.active) {
                        await widget.audio!.stop();
                      } else {
                        await widget.audio!.start();
                      }
                      if (mounted) setState(() => error = widget.audio!.error);
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            icon: Icon(listening ? Icons.mic_off_outlined : Icons.mic_none),
            label: Text(listening ? 'Stop microphone' : 'Start microphone'),
          ),
          const Text(
            'Foreground capture only. Listen for at least one second before sharing; stopping or putting the app in the background clears the clip.',
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: !busy && status['state'] == 'ready' && listening
              ? () => run('explain')
              : null,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Explain recent audio on device'),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.amber)),
        if (explanation != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POSSIBLE EXPLANATION · UNCONFIRMED',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    explanation!,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 32),
        const Text(
          'Optional internet assistance',
          style: TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 12),
        const Text(
          'Connect your configured assistance service. Its token stays in this screen’s memory. Nothing is sent until you choose Share this time.',
        ),
        TextField(
          controller: endpoint,
          decoration: const InputDecoration(
            labelText: 'Assistance service HTTPS address',
          ),
        ),
        TextField(
          controller: token,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Service token'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: !busy && listening
              ? () => onlineRequest(audio: true)
              : null,
          child: const Text('Analyze recent audio online'),
        ),
        TextField(
          controller: description,
          maxLength: 600,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Describe the sound or appliance to research',
          ),
        ),
        OutlinedButton(
          onPressed: !busy ? () => onlineRequest(audio: false) : null,
          child: const Text('Research this description'),
        ),
        if (onlineResult != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POSSIBLE EXPLANATION · UNCONFIRMED',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(onlineResult!.text),
                  for (final source in onlineResult!.citations)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (source['citedText'] is String)
                            Text(
                              source['citedText'] as String,
                              style: const TextStyle(fontSize: 12),
                            ),
                          TextButton(
                            onPressed: () =>
                                openSource(source['url'] as String),
                            child: Text(
                              source['title']?.toString() ?? 'Read source',
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final suggestions in onlineResult!.suggestions)
                    HtmlWidget(suggestions, onTapUrl: openSource),
                ],
              ),
            ),
          ),
        if ((explanation != null || onlineResult != null) && nativeRecognition)
          FilledButton.icon(
            onPressed: !busy && widget.runtime.state == 'listening'
                ? confirmAndTeach
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Confirm an interpretation & teach its sound'),
          ),
      ],
    ),
  );
}
