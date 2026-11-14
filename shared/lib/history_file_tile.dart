import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'receive_history.dart';

/// Presentation-only access to files already saved by the receiver.
class HistoryFileTile extends StatefulWidget {
  const HistoryFileTile({super.key, required this.entry});
  final ReceivedEntry entry;
  @override
  State<HistoryFileTile> createState() => _HistoryFileTileState();
}

class _HistoryFileTileState extends State<HistoryFileTile> {
  static const _channel = MethodChannel('app.nexodrop/history');
  late Future<int?> _size;
  @override
  void initState() {
    super.initState();
    _size = _readSize();
  }

  @override
  void didUpdateWidget(HistoryFileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _size = _readSize();
  }

  Future<int?> _readSize() async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<int>('size', {
          'id': widget.entry.id,
        });
      }
      final stat = await File(widget.entry.id).stat();
      return stat.type == FileSystemEntityType.file ? stat.size : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _open() async {
    try {
      if (Platform.isAndroid || Platform.isWindows) {
        await _channel.invokeMethod<void>('open', {'id': widget.entry.id});
      } else if (Platform.isLinux) {
        if (!await File(widget.entry.id).exists()) {
          throw const FileSystemException('Archivo no disponible');
        }
        final result = await Process.run('xdg-open', [widget.entry.id]);
        if (result.exitCode != 0) {
          throw const FileSystemException('No hay una aplicación disponible');
        }
      } else {
        throw UnsupportedError(
          'Abrir archivos aún no está disponible en esta plataforma',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir. Comprueba que el archivo existe y tienes una aplicación compatible.',
            ),
          ),
        );
      }
    }
  }

  IconData get _icon {
    final ext = widget.entry.name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (['mp4', 'mkv', 'webm'].contains(ext)) return Icons.movie_outlined;
    if (['mp3', 'wav', 'ogg'].contains(ext)) return Icons.audio_file_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _bytes(int size) {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(1)} MB';
    return '${(size / 1073741824).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.entry.date.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: FutureBuilder<int?>(
        future: _size,
        builder: (context, snapshot) => Text(
          '${snapshot.hasData ? _bytes(snapshot.data!) : 'Tamaño no disponible'} · $stamp',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      trailing: IconButton(
        tooltip: 'Abrir archivo',
        onPressed: _open,
        icon: const Icon(Icons.open_in_new_rounded, size: 20),
      ),
    );
  }
}
