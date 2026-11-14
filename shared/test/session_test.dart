import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/session.dart';
import 'package:nexodrop_shared/transfer.dart';

Future<void> until(bool Function() condition) async {
  final timer = Stopwatch()..start();
  while (!condition()) {
    if (timer.elapsed > const Duration(seconds: 4)) {
      throw TimeoutException('Estado no alcanzado');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late PeerSession a, b;
  late TransferService filesA, filesB;
  late Directory temp;
  final receivedA = <File>[];
  final receivedB = <File>[];
  var finishA = 0, finishB = 0;

  setUp(() async {
    a = PeerSession();
    b = PeerSession();
    filesA = TransferService();
    filesB = TransferService();
    temp = await Directory.systemTemp.createTemp('nexodrop-session-');
    receivedA.clear();
    receivedB.clear();
    finishA = 0;
    finishB = 0;
    await filesA.listen(
      directory: Directory('${temp.path}/a'),
      accept: (_) async => true,
      progress: (_, _) {},
      status: (_) {},
      finished: () => finishA++,
      received: receivedA.add,
      authorize: (id) =>
          a.connected && id == a.id && a.mode == TransferMode.receive,
      port: 0,
      bindAddress: '127.0.0.1',
    );
    await filesB.listen(
      directory: Directory('${temp.path}/b'),
      accept: (_) async => true,
      progress: (_, _) {},
      status: (_) {},
      finished: () => finishB++,
      received: receivedB.add,
      authorize: (id) =>
          b.connected && id == b.id && b.mode == TransferMode.receive,
      port: 0,
      bindAddress: '127.0.0.1',
    );
    await a.start(filesA.addresses, port: 0, bindAddress: '127.0.0.1');
    await b.start(filesB.addresses, port: 0, bindAddress: '127.0.0.1');
  });

  tearDown(() async {
    await a.disconnect();
    await b.disconnect();
    a.dispose();
    b.dispose();
    await filesA.stop();
    await filesB.stop();
    await temp.delete(recursive: true);
  });

  test(
    'Una vinculación permite enviar en ambos sentidos y conservar la sesión',
    () async {
      await b.connect(a.addresses.single);
      await until(() => a.connected && b.connected);
      final id = a.id;
      expect(b.id, id);
      await a.ensureReachable();
      await b.ensureReachable();
      expect(a.peer!.port, filesB.addresses.single.port);
      expect(b.peer!.port, filesA.addresses.single.port);
      await b.choose(TransferMode.send);
      await until(
        () => a.mode == TransferMode.receive && b.mode == TransferMode.send,
      );
      final first = await File(
        '${temp.path}/one.txt',
      ).writeAsString('Android a Fedora');
      await filesB.send(first, b.peer!, (_, _) {}, (_) {}, sessionId: b.id);
      await until(() => finishA == 1);
      expect(await receivedA.single.readAsString(), 'Android a Fedora');
      await a.choose(TransferMode.send);
      await until(
        () => b.mode == TransferMode.receive && a.mode == TransferMode.send,
      );
      final second = await File(
        '${temp.path}/two.txt',
      ).writeAsString('Fedora a Android');
      await filesA.send(second, a.peer!, (_, _) {}, (_) {}, sessionId: a.id);
      await until(() => finishB == 1);
      expect(await receivedB.single.readAsString(), 'Fedora a Android');
      expect(a.id, id);
      expect(b.id, id);
      expect(a.connected && b.connected, isTrue);
    },
  );

  test('No acepta archivos sin sesión ni en modo incorrecto', () async {
    await b.connect(a.addresses.single);
    await until(() => a.connected);
    final file = await File('${temp.path}/file').writeAsString('private');
    await expectLater(
      filesB.send(file, b.peer!, (_, _) {}, (_) {}, sessionId: b.id),
      throwsA(anything),
    );
    await until(() => finishA == 1);
    await b.choose(TransferMode.send);
    await until(() => a.mode == TransferMode.receive);
    await expectLater(
      filesB.send(file, b.peer!, (_, _) {}, (_) {}),
      throwsA(anything),
    );
    await until(() => finishA == 2);
    expect(receivedA, isEmpty);
  });

  test('Una clave incorrecta no vincula dispositivos', () async {
    final target = a.addresses.single;
    await expectLater(
      b.connect(Pairing(target.host, target.port, List.filled(32, 0))),
      throwsA(anything),
    );
    expect(a.connected, isFalse);
    expect(b.connected, isFalse);
  });

  test('La desconexión se refleja en ambos dispositivos', () async {
    await b.connect(a.addresses.single);
    await until(() => a.connected);
    await a.disconnect();
    await until(() => !b.connected);
    expect(b.peer, isNull);
    expect(b.mode, isNull);
  });

  test('No cambia roles durante una transferencia', () async {
    await b.connect(a.addresses.single);
    await until(() => a.connected);
    await b.choose(TransferMode.send);
    await until(() => a.mode == TransferMode.receive);
    b.setBusy(true);
    await until(() => a.peerBusy);
    await a.choose(TransferMode.send);
    expect(a.mode, TransferMode.receive);
    b.setBusy(false);
    await until(() => !a.peerBusy);
    await a.choose(TransferMode.send);
    await until(() => b.mode == TransferMode.receive);
  });
}
