import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../audio.dart';
import 'models.dart';
import 'store.dart';

bool get nativeRecognition =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class NativeRuntime {
  static const channel = MethodChannel('chimey/runtime');
  static final Stream<Map<Object?, Object?>> events =
      const EventChannel('chimey/runtime/events')
          .receiveBroadcastStream()
          .map((e) => Map<Object?, Object?>.from(e as Map))
          .asBroadcastStream();
  static Future<void> sync(SoundStore store) => channel.invokeMethod(
    'profiles',
    jsonEncode(store.sounds.map((p) => p.toJson()).toList()),
  );
}

class NativeCapture implements CaptureDevice {
  @override
  Future<bool> hasPermission() async => true; // Visible native permission flow runs in start.
  @override
  Future<Stream<Uint8List>> start() async {
    final output = StreamController<Uint8List>();
    final subscription = NativeRuntime.events.listen((event) {
      if (event['type'] == 'pcm' && !output.isClosed) {
        output.add(event['bytes'] as Uint8List);
      }
      if (event['type'] == 'status' && event['state'] == 'error') {
        output.addError(StateError(event['error'].toString()));
      }
      if (event['snapshot'] != true &&
          event['type'] == 'status' &&
          event['state'] == 'stopped' &&
          !output.isClosed) {
        output.close();
      }
    }, onError: output.addError);
    output.onCancel = subscription.cancel;
    try {
      await NativeRuntime.channel.invokeMethod('start');
    } catch (_) {
      await subscription.cancel();
      await output.close();
      rethrow;
    }
    return output.stream;
  }

  @override
  Future<void> stop() => NativeRuntime.channel.invokeMethod('stop');
  @override
  Future<void> dispose() async {}
}

class SoundRuntime extends ChangeNotifier {
  final store = SoundStore(PreferenceStorage());
  StreamSubscription<Map<Object?, Object?>>? _subscription;
  List<double>? features;
  String response = 'Listening for a sound.', state = 'stopped';
  String? error;
  double rms = 0, inferenceMs = 0;
  int featureSequence = 0;
  bool _closed = false;
  Future<void> initialize() async {
    await store.load();
    if (_closed || !nativeRecognition) return;
    try {
      await NativeRuntime.sync(store);
      final history = await NativeRuntime.channel.invokeMethod<String>(
        'events',
      );
      for (final item in (jsonDecode(history ?? '[]') as List).reversed) {
        final event = SoundEvent.fromJson(item as Map<String, dynamic>);
        if (!store.events.any((e) => e.id == event.id)) {
          await store.addEvent(event);
        } else {
          await store.updateDelivery(event.id, event.delivery);
        }
      }
      if (_closed) return;
      _subscription = NativeRuntime.events.listen(
        _receive,
        onError: (Object e) {
          error = e.toString();
          _notify();
        },
      );
    } catch (e) {
      error = 'Recognition unavailable: $e';
      _notify();
    }
  }

  void _receive(Map<Object?, Object?> e) {
    switch (e['type']) {
      case 'features':
        features = (e['features'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        rms = (e['rms'] as num).toDouble();
        inferenceMs = (e['elapsedMs'] as num).toDouble();
        featureSequence++;
      case 'recognition':
        response = switch (e['kind']) {
          'personal' => 'I heard ${e['label']}.',
          'category' => 'This sounds like ${e['label']}.',
          _ => 'I’m not sure what that sound is.',
        };
      case 'status':
        state = e['state'].toString();
        if (e['error'] != null) error = e['error'].toString();
      case 'event':
        unawaited(_saveEvent(e['event'] as String));
      case 'delivery':
        unawaited(
          _saveDelivery(e['eventId'].toString(), e['delivery'].toString()),
        );
    }
    _notify();
  }

  Future<void> _saveDelivery(String id, String delivery) async {
    try {
      await store.updateDelivery(id, delivery);
    } catch (e) {
      error = 'Unable to save delivery: $e';
      _notify();
    }
  }

  Future<void> _saveEvent(String json) async {
    try {
      await store.addEvent(
        SoundEvent.fromJson(jsonDecode(json) as Map<String, dynamic>),
      );
    } catch (e) {
      error = 'Unable to save activity: $e';
      _notify();
    }
  }

  Future<void> save(PersonalSound profile) async {
    if (nativeRecognition && profile.enabled && profile.rule.notification) {
      final granted =
          await NativeRuntime.channel.invokeMethod<bool>('notifications') ??
          false;
      if (!granted) {
        throw StateError(
          'Notification permission was denied. Enable it in Android settings, or choose a vibration or LED response.',
        );
      }
    }
    await store.upsert(profile);
    await _sync();
  }

  Future<void> remove(String id) async {
    await store.remove(id);
    await _sync();
  }

  Future<void> _sync() async {
    if (nativeRecognition) {
      try {
        await NativeRuntime.sync(store);
      } catch (e) {
        await NativeRuntime.channel.invokeMethod('stop');
        rethrow;
      }
    }
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_subscription?.cancel());
    store.dispose();
    super.dispose();
  }
}
