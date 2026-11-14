import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'transfer.dart';

enum TransferMode { send, receive }

/// Persistent, authenticated control link. Files use the existing streaming transport.
class PeerSession extends ChangeNotifier {
  ServerSocket? _server;
  SecureChannel? _channel;
  Timer? _heartbeat;
  bool _connecting = false;
  bool _disposed = false;
  bool _host = false;
  int _sent = 0;
  int _read = 0;
  final Map<String, Completer<void>> _probes = {};
  String? id;
  Pairing? peer;
  List<Pairing> addresses = [];
  TransferMode? mode;
  bool localBusy = false;
  bool peerBusy = false;
  String status = 'Preparando conexión…';
  Pairing? _files;

  bool get connected => peer != null && id != null;
  bool get connecting => _connecting;
  bool get busy => localBusy || peerBusy;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(
    List<Pairing> fileAddresses, {
    String? bindAddress,
    int port = 45874,
  }) async {
    if (_server != null) return;
    if (fileAddresses.isEmpty) {
      throw StateError('No hay una red local disponible.');
    }
    _files = fileAddresses.first;
    final key = await AesGcm.with256bits().newSecretKey();
    final bytes = await key.extractBytes();
    final server = await ServerSocket.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      port,
    );
    if (_disposed) {
      await server.close();
      return;
    }
    _server = server;
    addresses = [
      for (final entry in fileAddresses)
        Pairing(entry.host, server.port, bytes),
    ];
    status = 'Listo para conectar';
    _notify();
    server.listen((socket) async {
      if (_connecting || connected || _disposed) {
        socket.destroy();
        return;
      }
      _connecting = true;
      final channel = SecureChannel(socket, bytes);
      _channel = channel;
      _notify();
      try {
        final hello = await channel
            .receive('nexodrop-session-hello')
            .timeout(const Duration(seconds: 12));
        final client = _validId(hello['nonce']);
        final challenge = randomId();
        final remoteFiles = _remote(
          socket.remoteAddress.address,
          hello['files'],
        );
        await channel.send({
          'nonce': challenge,
          'files': _files!.code,
        }, '$client:session-answer');
        final confirm = await channel
            .receive('$client:$challenge:confirm')
            .timeout(const Duration(seconds: 12));
        if (confirm['ok'] != true) {
          throw const FormatException('Confirmación inválida.');
        }
        await channel.send({'ok': true}, '$client:$challenge:ready');
        _activate(channel, remoteFiles, '$client:$challenge', true);
      } catch (_) {
        channel.close();
        if (identical(_channel, channel)) {
          _channel = null;
          status = 'No se pudo conectar. Vuelve a escanear el QR.';
        }
      } finally {
        _connecting = false;
        _notify();
      }
    });
  }

  String _validId(dynamic value) {
    if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(value)) {
      throw const FormatException('Sesión inválida.');
    }
    return value;
  }

  Pairing _remote(String host, dynamic value) {
    if (value is! String || value.length > 1024) {
      throw const FormatException('Conexión inválida.');
    }
    final parsed = Pairing.parse(value);
    // Use the actual control socket peer, never a supplied third-party address.
    return Pairing(host, parsed.port, parsed.key);
  }

  Future<void> connect(Pairing target) async {
    if (_connecting || connected) {
      throw StateError('Ya hay una conexión activa.');
    }
    if (_files == null) throw StateError('La red aún no está preparada.');
    _connecting = true;
    status = 'Conectando…';
    _notify();
    SecureChannel? channel;
    try {
      final socket = await Socket.connect(
        target.host,
        target.port,
        timeout: const Duration(seconds: 10),
      );
      channel = SecureChannel(socket, target.key);
      _channel = channel;
      final client = randomId();
      await channel.send({
        'nonce': client,
        'files': _files!.code,
      }, 'nexodrop-session-hello');
      final answer = await channel
          .receive('$client:session-answer')
          .timeout(const Duration(seconds: 12));
      final challenge = _validId(answer['nonce']);
      final remote = _remote(socket.remoteAddress.address, answer['files']);
      await channel.send({'ok': true}, '$client:$challenge:confirm');
      final ready = await channel
          .receive('$client:$challenge:ready')
          .timeout(const Duration(seconds: 12));
      if (ready['ok'] != true) {
        throw const FormatException('Sesión no confirmada.');
      }
      if (_disposed) {
        channel.close();
        return;
      }
      _activate(channel, remote, '$client:$challenge', false);
    } catch (_) {
      channel?.close();
      _channel = null;
      status = 'No se pudo conectar. Comprueba la red y escanea el QR actual.';
      rethrow;
    } finally {
      _connecting = false;
      _notify();
    }
  }

  void _activate(
    SecureChannel channel,
    Pairing remote,
    String sessionId,
    bool host,
  ) {
    if (_disposed) {
      channel.close();
      return;
    }
    _channel = channel;
    peer = remote;
    id = sessionId;
    _host = host;
    _sent = 0;
    _read = 0;
    mode = null;
    status = 'Dispositivo conectado';
    _outgoing = Future.value();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_send({'type': 'ping'})),
    );
    unawaited(_readMessages(channel, sessionId));
    _notify();
  }

  Future<void> _outgoing = Future.value();
  Future<void> _send(Map<String, dynamic> data) {
    final channel = _channel;
    final sessionId = id;
    if (channel == null || sessionId == null) return Future.value();
    final context = '$sessionId:${_host ? 'host' : 'guest'}:${_sent++}';
    _outgoing = _outgoing
        .then((_) async {
          if (!identical(channel, _channel)) return;
          await channel.send(data, context);
        })
        .catchError((Object _) {
          if (identical(channel, _channel)) _lost();
        });
    return _outgoing;
  }

  Future<void> _readMessages(SecureChannel channel, String sessionId) async {
    try {
      while (identical(channel, _channel) && connected) {
        final data = await channel.receive(
          '$sessionId:${_host ? 'guest' : 'host'}:${_read++}',
          idleTimeout: null,
        );
        if (!identical(channel, _channel)) return;
        switch (data['type']) {
          case 'ping':
            if (data['probe'] is String) {
              await _send({'type': 'pong', 'probe': data['probe']});
            }
            break;
          case 'pong':
            final probe = _probes.remove(data['probe']);
            if (probe != null && !probe.isCompleted) probe.complete();
          case 'choose':
            if (!_host || busy) break;
            final requested = data['mode'];
            if (requested != 'send' && requested != 'receive') {
              throw const FormatException('Modo inválido.');
            }
            mode = requested == 'send'
                ? TransferMode.receive
                : TransferMode.send;
            await _send({'type': 'mode', 'hostMode': mode!.name});
          case 'mode':
            if (_host) throw const FormatException('Mensaje inválido.');
            if (data['hostMode'] != 'send' && data['hostMode'] != 'receive') {
              throw const FormatException('Modo inválido.');
            }
            mode = data['hostMode'] == 'send'
                ? TransferMode.receive
                : TransferMode.send;
          case 'busy':
            peerBusy = data['value'] == true;
          default:
            throw const FormatException('Mensaje desconocido.');
        }
        _notify();
      }
    } catch (_) {
      if (identical(channel, _channel)) _lost();
    }
  }

  Future<void> ensureReachable() async {
    if (!connected) throw StateError('No hay un dispositivo conectado.');
    final token = randomId();
    final result = Completer<void>();
    _probes[token] = result;
    // Install the timeout/error handler before sending, since send can close the link.
    final response = result.future.timeout(const Duration(seconds: 15));
    unawaited(_send({'type': 'ping', 'probe': token}));
    try {
      await response;
    } catch (_) {
      _lost();
      throw const SocketException(
        'El otro dispositivo no responde. Comprueba la conexión.',
      );
    } finally {
      _probes.remove(token);
    }
  }

  Future<void> choose(TransferMode value) async {
    if (!connected || busy) return;
    if (_host) {
      mode = value;
      _notify();
      await _send({'type': 'mode', 'hostMode': value.name});
    } else {
      await _send({'type': 'choose', 'mode': value.name});
    }
  }

  void setBusy(bool value) {
    localBusy = value;
    unawaited(_send({'type': 'busy', 'value': value}));
    _notify();
  }

  void _lost() {
    for (final probe in _probes.values) {
      if (!probe.isCompleted) {
        probe.completeError(const SocketException('Conexión cerrada.'));
      }
    }
    _probes.clear();
    _channel?.close();
    _channel = null;
    _heartbeat?.cancel();
    peer = null;
    id = null;
    mode = null;
    peerBusy = false;
    localBusy = false;
    status = 'Conexión cerrada. Vuelve a vincular los dispositivos.';
    _notify();
  }

  Future<void> disconnect() async {
    _lost();
    await _server?.close();
    _server = null;
    addresses = [];
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
