import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

abstract interface class SoundStorage {
  Future<String?> read();
  Future<void> write(String json);
}

class PreferenceStorage implements SoundStorage {
  static const key = 'chimey.sounds.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String json) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, json)) {
      throw StateError('Could not save sound library');
    }
  }
}

class SoundStore extends ChangeNotifier {
  SoundStore(this.storage);
  final SoundStorage storage;
  List<PersonalSound> _sounds = [];
  List<SoundEvent> _events = [];
  Map<String, int> _lastActions = {};
  bool loaded = false, _closed = false;
  String? error;
  Future<void> _writes = Future.value();
  List<PersonalSound> get sounds => List.unmodifiable(_sounds);
  List<SoundEvent> get events => List.unmodifiable(_events);
  Map<String, int> get lastActions => Map.unmodifiable(_lastActions);
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final text = await storage.read();
      if (text != null) {
        final json = jsonDecode(text) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Unsupported sound library version');
        }
        final sounds = (json['sounds'] as List)
            .map((v) => PersonalSound.fromJson(v as Map<String, dynamic>))
            .toList();
        final events = (json['events'] as List)
            .map((v) => SoundEvent.fromJson(v as Map<String, dynamic>))
            .toList();
        if (sounds.length > 100 ||
            sounds.map((s) => s.id).toSet().length != sounds.length ||
            events.length > 200) {
          throw const FormatException('Invalid sound library');
        }
        _lastActions = (json['lastActions'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as int),
        );
        _sounds = sounds;
        _events = events;
      }
      error = null;
    } catch (_) {
      error =
          'Sound library could not be loaded. Original data has been preserved.';
    }
    loaded = true;
    _notify();
  }

  Future<void> upsert(PersonalSound sound) => _change(() {
    // Validate serialized content before committing to disk.
    PersonalSound.fromJson(sound.toJson());
    final index = _sounds.indexWhere((s) => s.id == sound.id);
    if (index < 0) {
      if (_sounds.length >= 100) throw StateError('Sound library is full');
      _sounds.add(sound);
    } else {
      _sounds[index] = sound;
    }
  });
  Future<void> remove(String id) => _change(() {
    _sounds.removeWhere((s) => s.id == id);
    _lastActions.remove(id);
  });
  Future<void> addEvent(SoundEvent event, {Map<String, int>? lastActions}) =>
      _change(() {
        _events.insert(0, event);
        if (_events.length > 200) _events.removeRange(200, _events.length);
        if (lastActions != null) _lastActions = Map.of(lastActions);
      });
  Future<void> correct(String eventId, String label) => _change(() {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index < 0 || label.trim().isEmpty) {
      throw ArgumentError('Select an event and a correction');
    }
    _events[index] = _events[index].corrected(label.trim());
  });
  Future<void> updateDelivery(String eventId, String delivery) => _change(() {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index >= 0) _events[index] = _events[index].withDelivery(delivery);
  });
  Future<void> clearEvents() => _change(() => _events.clear());
  Future<void> _change(void Function() change) {
    final task = _writes.then((_) async {
      if (!loaded || error != null) {
        throw StateError('Load and recover the library before editing it');
      }
      final previousSounds = List<PersonalSound>.of(_sounds);
      final previousEvents = List<SoundEvent>.of(_events);
      final previousActions = Map<String, int>.of(_lastActions);
      try {
        change();
        await storage.write(
          jsonEncode({
            'version': 1,
            'sounds': _sounds.map((s) => s.toJson()).toList(),
            'events': _events.map((e) => e.toJson()).toList(),
            'lastActions': _lastActions,
          }),
        );
      } catch (_) {
        _sounds = previousSounds;
        _events = previousEvents;
        _lastActions = previousActions;
        rethrow;
      }
      _notify();
    });
    _writes = task.catchError((Object _) {});
    return task;
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
