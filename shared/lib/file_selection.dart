import 'dart:io';
import 'package:flutter/foundation.dart';

/// The selection is consumed only after the receiver confirms the transfer.
class FileSelection extends ChangeNotifier {
  File? file;
  bool sending = false;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void select(File value) {
    if (sending) throw StateError('Hay un envío en curso.');
    file = value;
    _changed();
  }

  bool clear() {
    if (sending) return false;
    file = null;
    _changed();
    return true;
  }

  Future<void> send(Future<void> Function(File) transfer) async {
    final selected = file;
    if (selected == null || sending) {
      throw StateError('No hay un archivo disponible para enviar.');
    }
    sending = true;
    _changed();
    try {
      await transfer(selected);
      file = null;
    } finally {
      sending = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
