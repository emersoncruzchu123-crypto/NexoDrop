import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/session.dart';
import 'package:nexodrop_shared/transfer.dart';

void main() {
  test(
    'Mantiene la sesión más de 90 segundos aunque el emisor no envíe latidos',
    () async {
      final host = PeerSession();
      SecureChannel? channel;
      try {
        final files = Pairing('127.0.0.1', 45873, List.generate(32, (i) => i));
        await host.start([files], bindAddress: '127.0.0.1', port: 0);
        final target = host.addresses.single;
        final socket = await Socket.connect(target.host, target.port);
        channel = SecureChannel(socket, target.key);
        final client = randomId();
        await channel.send({
          'nonce': client,
          'files': files.code,
        }, 'nexodrop-session-hello');
        final answer = await channel.receive('$client:session-answer');
        final id = '$client:${answer['nonce']}';
        await channel.send({'ok': true}, '$id:confirm');
        await channel.receive('$id:ready');
        await Future<void>.delayed(const Duration(seconds: 95));
        expect(host.connected, isTrue);
        expect(host.id, id);
        await channel.send({'type': 'choose', 'mode': 'send'}, '$id:guest:0');
        final deadline = Stopwatch()..start();
        while (host.mode != TransferMode.receive) {
          if (deadline.elapsed > const Duration(seconds: 3)) {
            throw TimeoutException('La sesión no respondió');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(host.connected, isTrue);
      } finally {
        channel?.close();
        await host.disconnect();
        host.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
