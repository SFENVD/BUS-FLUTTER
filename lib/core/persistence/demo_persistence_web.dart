import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'demo_persistence.dart';

DemoPersistence createDemoPersistence() {
  try {
    const probe = 'school-bus-demo.v1.probe';
    web.window.localStorage.setItem(probe, '1');
    web.window.localStorage.removeItem(probe);
    return _BrowserDemoPersistence();
  } catch (_) {
    // Browsers may disable storage in private or restricted contexts.
    return MemoryDemoPersistence();
  }
}

class _BrowserDemoPersistence implements DemoPersistence {
  static const _prefix = 'school-bus-demo.v1.';
  final _changes = StreamController<String>.broadcast(sync: true);
  late final JSFunction _listener;
  final _fallback = MemoryDemoPersistence();
  bool _durable = true;

  _BrowserDemoPersistence() {
    _listener = ((web.Event event) {
      final key = (event as web.StorageEvent).key;
      if (key == null) {
        _changes.add('*');
      } else if (key == '${_prefix}reset') {
        if (event.newValue != null) _changes.add('*');
      } else if (key.startsWith(_prefix)) {
        _changes.add(key.substring(_prefix.length));
      }
    }).toJS;
    web.window.addEventListener('storage', _listener);
  }

  @override
  bool get isDurable => _durable;

  @override
  Stream<String> get changes => _changes.stream;

  @override
  Map<String, Object?>? read(String key) {
    if (!_durable) return _fallback.read(key);
    try {
      final data = decodeDemoData(
        web.window.localStorage.getItem('$_prefix$key'),
      );
      if (data != null) _fallback.write(key, data);
      return data;
    } catch (_) {
      _durable = false;
      return _fallback.read(key);
    }
  }

  @override
  void write(String key, Map<String, Object?> value) {
    _fallback.write(key, value);
    if (!_durable) return;
    final encoded = jsonEncode(value);
    try {
      final storage = web.window.localStorage;
      if (storage.getItem('$_prefix$key') != encoded) {
        storage.setItem('$_prefix$key', encoded);
      }
    } catch (_) {
      _durable = false;
    }
  }

  @override
  void clear() {
    _fallback.clear();
    try {
      final storage = web.window.localStorage;
      final keys = [
        for (var index = 0; index < storage.length; index++) storage.key(index),
      ];
      for (final key in keys) {
        if (key != null && key.startsWith(_prefix)) storage.removeItem(key);
      }
    } catch (_) {
      _durable = false;
    }
    _changes.add('*');
    if (_durable) {
      try {
        web.window.localStorage.setItem(
          '${_prefix}reset',
          DateTime.now().microsecondsSinceEpoch.toString(),
        );
      } catch (_) {
        _durable = false;
      }
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('storage', _listener);
    _changes.close();
    _fallback.dispose();
  }
}
