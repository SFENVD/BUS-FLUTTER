import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo business data only. Authentication sessions and passwords are not saved.
abstract interface class DemoPersistence {
  bool get isDurable;
  Map<String, Object?>? read(String key);
  void write(String key, Map<String, Object?> value);
  void clear();
  Stream<String> get changes;
  void dispose();
}

/// Each ProviderContainer has isolated data unless a store is explicitly shared.
final demoPersistenceProvider = Provider<DemoPersistence>((ref) {
  final store = MemoryDemoPersistence();
  ref.onDispose(store.dispose);
  return store;
});

class MemoryDemoPersistence implements DemoPersistence {
  final Map<String, String> _values = {};
  final _changes = StreamController<String>.broadcast(sync: true);

  @override
  bool get isDurable => false;

  @override
  Stream<String> get changes => _changes.stream;

  @override
  Map<String, Object?>? read(String key) => decodeDemoData(_values[key]);

  @override
  void write(String key, Map<String, Object?> value) {
    _values[key] = jsonEncode(value);
  }

  /// Simulates a browser storage event without echoing local writes.
  void receiveExternal(String key, Map<String, Object?> value) {
    write(key, value);
    _changes.add(key);
  }

  @override
  void clear() {
    _values.clear();
    _changes.add('*');
  }

  @override
  void dispose() => _changes.close();
}

Map<String, Object?>? decodeDemoData(String? value) {
  if (value == null) return null;
  try {
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// A corrupt or older demo snapshot must not prevent the application starting.
T restoreDemoData<T>(T fallback, T Function() restore) {
  try {
    return restore();
  } on FormatException {
    return fallback;
  } on TypeError {
    return fallback;
  } on StateError {
    return fallback;
  } on ArgumentError {
    return fallback;
  }
}
