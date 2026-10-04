import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chimey/sounds/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fresh platform preferences load an empty editable library', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SoundStore(PreferenceStorage());
    await store.load();
    expect(store.loaded, isTrue);
    expect(store.error, isNull);
    expect(store.sounds, isEmpty);
    await store.clearEvents();
    final restored = SoundStore(PreferenceStorage());
    await restored.load();
    expect(restored.error, isNull);
    expect(restored.events, isEmpty);
  });
}
