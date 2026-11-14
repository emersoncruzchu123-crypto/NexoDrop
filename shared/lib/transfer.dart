import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'received_files.dart';
import 'transfer_utils.dart';
export 'transfer_utils.dart' show randomId, safeName;

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

const chunkSize = 64 * 1024;

class Pairing {
  final String host;
  final int port;
  final List<int> key;
  Pairing(this.host, this.port, this.key);
  factory Pairing.parse(String code) {
    final uri = Uri.parse(code.trim());
    if (uri.scheme != 'nexodrop' ||
        uri.host.isEmpty ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException('Código de conexión inválido.');
    }
    final key = base64Url.decode(uri.fragment);
    if (key.length != 32) throw const FormatException('Clave inválida.');
    return Pairing(uri.host, uri.port, key);
  }
  String get code => Uri(
    scheme: 'nexodrop',
    host: host,
    port: port,
    fragment: base64UrlEncode(key),
  ).toString();
}

// Length-prefixed authenticated frames. Each allocation is bounded before read.
class SecureChannel {
  final Socket socket;
  final SecretKey key;
  final StreamIterator<Uint8List> _input;
  final _cipher = AesGcm.with256bits();
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;
  SecureChannel(this.socket, List<int> key)
    : key = SecretKey(key),
      _input = StreamIterator(socket);

  Future<Uint8List> _read(
    int length, {
    Duration? timeout = const Duration(seconds: 90),
  }) async {
    final out = Uint8List(length);
    var filled = 0;
    while (filled < length) {
      if (_offset == _buffer.length) {
        final next = _input.moveNext();
        if (!await (timeout == null ? next : next.timeout(timeout))) {
          throw const SocketException('La otra parte cerró la conexión.');
        }
        _buffer = _input.current;
        _offset = 0;
      }
      final count = min(length - filled, _buffer.length - _offset);
      out.setRange(filled, filled + count, _buffer, _offset);
      _offset += count;
      filled += count;
    }
    return out;
  }

  Future<void> send(Map<String, dynamic> value, String context) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: key,
      aad: utf8.encode(context),
    );
    final packet = box.concatenation();
    final header = ByteData(4)..setUint32(0, packet.length);
    socket.add(header.buffer.asUint8List());
    socket.add(packet);
    await socket.flush().timeout(const Duration(seconds: 90));
  }

  Future<Map<String, dynamic>> receive(
    String context, {
    Duration? idleTimeout = const Duration(seconds: 90),
  }) async {
    final header = await _read(4, timeout: idleTimeout);
    final length = ByteData.sublistView(header).getUint32(0);
    if (length < 28 || length > 100000) {
      throw const FormatException('Tamaño de mensaje inválido.');
    }
    final packet = await _read(length);
    final clear = await _cipher.decrypt(
      SecretBox.fromConcatenation(packet, nonceLength: 12, macLength: 16),
      secretKey: key,
      aad: utf8.encode(context),
    );
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }

  void close() {
    socket.destroy();
    unawaited(_input.cancel());
  }
}

class Offer {
  final String id;
  final String name;
  final int size;
  final String hash;
  Offer(this.id, this.name, this.size, this.hash);
  factory Offer.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final size = json['size'] as int;
    final hash = json['hash'] as String;
    if (id.length != 32 ||
        name.length > 1024 ||
        size < 0 ||
        size > 10 * 1024 * 1024 * 1024 * 1024 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Solicitud inválida.');
    }
    return Offer(id, safeName(name), size, hash);
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'hash': hash,
  };
}

typedef Progress = void Function(int done, int total);

class TransferService {
  ServerSocket? _server;
  SecureChannel? _active;
  bool _busy = false;
  bool _cancelled = false;
  final Set<String> _seen = {};
  List<Pairing> addresses = [];
  bool get listening => _server != null;
  void cancel() {
    _cancelled = true;
    _active?.close();
  }

  void _checkCancelled() {
    if (_cancelled) throw const SocketException('Transferencia cancelada.');
  }

  Future<void> stop() async {
    cancel();
    await _server?.close();
    _server = null;
    addresses = [];
  }

  Future<void> listen({
    required Directory directory,
    required Future<bool> Function(Offer) accept,
    required Progress progress,
    required void Function(String) status,
    required void Function() finished,
    void Function(File)? received,
    Future<String> Function(File)? saveReceived,
    bool Function(String?)? authorize,
    int port = 45873,
    String? bindAddress,
  }) async {
    if (_server != null) return;
    final key = await AesGcm.with256bits().newSecretKey();
    final bytes = await key.extractBytes();
    final server = await ServerSocket.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      port,
    );
    _server = server;
    _seen.clear();
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    addresses = [
      for (final interface in interfaces)
        for (final ip in interface.addresses)
          Pairing(ip.address, server.port, bytes),
    ];
    if (bindAddress != null) {
      addresses = [Pairing(bindAddress, server.port, bytes)];
    }
    server.listen((socket) async {
      // Bound concurrent work and replay memory; restart reception to renew key.
      if (_busy || _seen.length >= 1000) {
        socket.destroy();
        return;
      }
      _busy = true;
      _cancelled = false;
      final channel = SecureChannel(socket, bytes);
      _active = channel;
      File? partial;
      RandomAccessFile? output;
      try {
        final message = await channel.receive('nexodrop-v1-offer');
        if (authorize != null && !authorize(message['session'] as String?)) {
          throw const FormatException('Sesión no autorizada.');
        }
        final offer = Offer.fromJson(message);
        if (!_seen.add(offer.id)) {
          throw const FormatException('Solicitud repetida.');
        }
        status('Solicitud: ${offer.name}');
        final accepted = await accept(
          offer,
        ).timeout(const Duration(seconds: 60), onTimeout: () => false);
        _checkCancelled();
        await channel.send({'accepted': accepted}, '${offer.id}:answer');
        if (!accepted) {
          status('Transferencia rechazada.');
          return;
        }
        await directory.create(recursive: true);
        partial = await createTransferPartial(directory);
        output = await partial.open(mode: FileMode.write);
        var done = 0;
        var sequence = 0;
        progress(0, offer.size);
        while (done < offer.size) {
          final frame = await channel.receive('${offer.id}:data:${sequence++}');
          _checkCancelled();
          final data = base64Decode(frame['data'] as String);
          if (data.isEmpty ||
              data.length > chunkSize ||
              done + data.length > offer.size) {
            throw const FormatException('Contenido inválido.');
          }
          await output.writeFrom(data);
          done += data.length;
          progress(done, offer.size);
        }
        // Explicit authenticated EOF protects zero-byte files and truncation.
        final end = await channel.receive('${offer.id}:end:$sequence');
        if (end['end'] != true) throw const FormatException('Final inválido.');
        await output.close();
        output = null;
        status('Comprobando integridad…');
        final digest = await sha256
            .bind(
              partial.openRead().map((chunk) {
                _checkCancelled();
                return chunk;
              }),
            )
            .first;
        _checkCancelled();
        if (digest.toString() != offer.hash) {
          throw const FormatException(
            'El archivo no coincide con el original.',
          );
        }
        final saved = await publishReceivedFile(partial, directory, offer.name);
        partial = null; // Keep verified files even if acknowledgement fails.
        if (saveReceived != null) status('Guardando archivo en NexoDrop…');
        final location = await saveReceived?.call(saved) ?? saved.path;
        received?.call(saved);
        status('Recibido y verificado: $location');
        await channel.send({
          'ok': true,
          'hash': digest.toString(),
        }, '${offer.id}:result');
      } catch (error) {
        status(
          _cancelled
              ? 'Transferencia cancelada.'
              : 'No se completó la recepción: $error',
        );
      } finally {
        await output?.close();
        if (partial != null && await partial.exists()) {
          await partial.delete();
        }
        channel.close();
        _active = null;
        _busy = false;
        finished();
      }
    });
  }

  Future<void> send(
    File file,
    Pairing target,
    Progress progress,
    void Function(String) status, {
    String? sessionId,
  }) async {
    if (_busy) throw StateError('Ya hay una transferencia en curso.');
    _busy = true;
    _cancelled = false;
    RandomAccessFile? input;
    try {
      status('Calculando la huella del archivo…');
      final hash = await sha256
          .bind(
            file.openRead().map((chunk) {
              _checkCancelled();
              return chunk;
            }),
          )
          .first;
      _checkCancelled();
      final offer = Offer(
        randomId(),
        safeName(file.uri.pathSegments.last),
        await file.length(),
        hash.toString(),
      );
      final socket = await Socket.connect(
        target.host,
        target.port,
        timeout: const Duration(seconds: 10),
      );
      final channel = SecureChannel(socket, target.key);
      _active = channel;
      _checkCancelled();
      await channel.send({
        ...offer.toJson(),
        'session': ?sessionId,
      }, 'nexodrop-v1-offer');
      status('Esperando aceptación en el receptor…');
      final answer = await channel.receive('${offer.id}:answer');
      if (answer['accepted'] != true) {
        throw StateError('El receptor rechazó el archivo.');
      }
      input = await file.open();
      var done = 0;
      var sequence = 0;
      progress(0, offer.size);
      while (done < offer.size) {
        _checkCancelled();
        final data = await input.read(min(chunkSize, offer.size - done));
        if (data.isEmpty) {
          throw StateError('El archivo cambió durante el envío.');
        }
        await channel.send({
          'data': base64Encode(data),
        }, '${offer.id}:data:${sequence++}');
        done += data.length;
        progress(done, offer.size);
      }
      await channel.send({'end': true}, '${offer.id}:end:$sequence');
      status('Esperando verificación del receptor…');
      final result = await channel.receive(
        '${offer.id}:result',
        idleTimeout: null,
      );
      if (result['ok'] != true || result['hash'] != offer.hash) {
        throw StateError('El receptor no confirmó la integridad.');
      }
      status('Enviado y verificado: ${offer.name}');
    } finally {
      await input?.close();
      _active?.close();
      _active = null;
      _busy = false;
    }
  }
}
