import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class ReceivedEntry {
  const ReceivedEntry({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
  });
  final String id, name, location;
  final DateTime date;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'date': date.toIso8601String(),
  };
  factory ReceivedEntry.fromJson(Map<String, dynamic> data) => ReceivedEntry(
    id: data['id'] as String,
    name: data['name'] as String,
    location: data['location'] as String,
    date: DateTime.parse(data['date'] as String),
  );
}

class ReceiveHistory {
  ReceiveHistory(this.file);
  final File file;
  final List<ReceivedEntry> _entries = [];
  List<ReceivedEntry> get entries => List.unmodifiable(_entries);
  final Set<String> _savedIds = {};
  bool hasSaved(String id) => _savedIds.contains(id);
  bool existed = false;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    existed = await file.exists();
    _entries.clear();
    _savedIds.clear();
    if (existed) {
      final data = jsonDecode(await file.readAsString());
      final list = data is List ? data : data['entries'] as List;
      _entries.addAll(
        list.map(
          (item) =>
              ReceivedEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
      _savedIds.addAll(
        data is List
            ? _entries.map((e) => e.id)
            : (data['savedIds'] as List).cast<String>(),
      );
    }
  }

  Future<void> _write(List<ReceivedEntry> next) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final ids = {..._savedIds, ...next.map((e) => e.id)};
    await temporary.writeAsString(
      jsonEncode({
        'entries': next.map((e) => e.toJson()).toList(),
        'savedIds': ids.toList(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
    _entries
      ..clear()
      ..addAll(next);
    _savedIds
      ..clear()
      ..addAll(ids);
    existed = true;
  }

  Future<void> _queue(Future<void> Function() action) {
    final work = _pending.then((_) => action());
    _pending = work.catchError((Object _) {});
    return work;
  }

  Future<void> add(ReceivedEntry entry) => _queue(
    () => _write([..._entries.where((item) => item.id != entry.id), entry]),
  );
  Future<void> clear() => _queue(() => _write([]));
}

class ReceivedFileSaver {
  ReceivedFileSaver({required this.history, bool? android})
    : _android = android ?? Platform.isAndroid;
  final ReceiveHistory history;
  final bool _android;
  static const _channel = MethodChannel('app.nexodrop/files');

  Future<String> save(File file) async {
    final ReceivedEntry entry;
    if (_android) {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'saveToDownloads',
        {'path': file.path},
      );
      if (result == null) {
        throw const FileSystemException('Android no confirmó el guardado.');
      }
      entry = ReceivedEntry(
        id: result['id'] as String,
        name: result['name'] as String,
        location: result['location'] as String,
        date: DateTime.now(),
      );
    } else {
      entry = ReceivedEntry(
        id: file.path,
        name: file.uri.pathSegments.last,
        location: file.path,
        date: DateTime.now(),
      );
    }
    if (!history.hasSaved(entry.id)) await history.add(entry);
    // Never discard the only copy: publication and durable history must finish first.
    if (_android) {
      try {
        await file.delete();
      } on FileSystemException {
        /* Retry cleanup on next startup. */
      }
    }
    return entry.location;
  }
}
