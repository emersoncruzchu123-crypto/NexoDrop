import 'dart:io';
import 'package:flutter/services.dart';

/// Serializes native transitions so disconnect cannot be overtaken by a late start.
class ConnectionBackground {
  ConnectionBackground({bool? enabled})
    : _enabled = enabled ?? Platform.isAndroid;
  final bool _enabled;
  static const _channel = MethodChannel('app.nexodrop/connection');
  Future<void> _pending = Future.value();
  bool _active = false;

  Future<void> update(bool connected) {
    if (!_enabled) return Future.value();
    final operation = _pending.then((_) async {
      if (_active == connected) return;
      await _channel.invokeMethod<void>('setConnected', {
        'connected': connected,
      });
      _active = connected;
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
