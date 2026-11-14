import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/transfer.dart';

void main() {
  late Directory temp;
  late Directory destination;
  late TransferService receiver;
  late TransferService sender;
  late Completer<void> finished;
  late List<String> statuses;
  File? received;

  Future<Pairing> start({
    bool accept = true,
    Future<String> Function(File)? saveReceived,
    void Function(int, int)? progress,
  }) async {
    await receiver.listen(
      directory: destination,
      accept: (_) async => accept,
      progress: progress ?? (_, _) {},
      status: statuses.add,
      received: (file) => received = file,
      saveReceived: saveReceived,
      finished: () {
        if (!finished.isCompleted) finished.complete();
      },
      port: 0,
      bindAddress: '127.0.0.1',
    );
    return receiver.addresses.single;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('nexodrop-test-');
    destination = Directory('${temp.path}/received');
    receiver = TransferService();
    sender = TransferService();
    finished = Completer<void>();
    statuses = [];
    received = null;
  });
  tearDown(() async {
    await sender.stop();
    await receiver.stop();
    await temp.delete(recursive: true);
  });

  for (final size in [0, 1, 200000]) {
    test(
      'Transferencia cifrada de $size bytes conserva el contenido',
      () async {
        final target = await start();
        final data = List.generate(size, (i) => i % 251);
        final file = await File('${temp.path}/prueba.bin').writeAsBytes(data);
        await sender.send(
          file,
          Pairing.parse(target.code),
          (_, _) {},
          statuses.add,
        );
        await finished.future;
        expect(await received!.readAsBytes(), data);
        expect(received!.parent.path, destination.path);
        expect(
          (await destination.list().toList()).whereType<Directory>(),
          isEmpty,
        );
        expect(statuses.last, contains('verificado'));
      },
    );
  }

  test('Rechazar no guarda archivos', () async {
    final target = await start(accept: false);
    final file = await File('${temp.path}/file').writeAsString('privado');
    await expectLater(
      sender.send(file, target, (_, _) {}, statuses.add),
      throwsStateError,
    );
    await finished.future;
    expect(await destination.exists(), isFalse);
  });

  test('Clave incorrecta no permite recibir', () async {
    final target = await start();
    final file = await File('${temp.path}/file').writeAsString('privado');
    final wrong = Pairing(target.host, target.port, List.filled(32, 0));
    await expectLater(
      sender.send(file, wrong, (_, _) {}, statuses.add),
      throwsA(anything),
    );
    await finished.future;
    expect(received, isNull);
    expect(await destination.exists(), isFalse);
  });

  test('Hash incorrecto elimina el archivo parcial', () async {
    final target = await start();
    final socket = await Socket.connect(target.host, target.port);
    final channel = SecureChannel(socket, target.key);
    final offer = Offer(
      randomId(),
      '../escape.txt',
      3,
      sha256.convert([9]).toString(),
    );
    await channel.send(offer.toJson(), 'nexodrop-v1-offer');
    await channel.receive('${offer.id}:answer');
    await channel.send({'data': 'AQID'}, '${offer.id}:data:0');
    await channel.send({'end': true}, '${offer.id}:end:1');
    await finished.future;
    channel.close();
    expect(received, isNull);
    expect(await destination.list().toList(), isEmpty);
    expect(statuses.last, contains('no coincide'));
  });

  test('Cancelar durante la recepción elimina el parcial', () async {
    final target = await start(
      progress: (done, _) {
        if (done > 0) receiver.cancel();
      },
    );
    final file = await File(
      '${temp.path}/large',
    ).writeAsBytes(List.filled(400000, 7));
    await expectLater(
      sender.send(file, target, (_, _) {}, statuses.add),
      throwsA(anything),
    );
    await finished.future;
    expect(received, isNull);
    expect(await destination.list().toList(), isEmpty);
  });

  test('No acepta encabezados que exceden el límite', () async {
    final target = await start();
    final socket = await Socket.connect(target.host, target.port);
    socket.add((ByteData(4)..setUint32(0, 0xffffffff)).buffer.asUint8List());
    await socket.flush();
    await finished.future;
    socket.destroy();
    expect(statuses.last, contains('Tamaño de mensaje inválido'));
  });

  test('Un bloque fuera de secuencia no se guarda', () async {
    final target = await start();
    final socket = await Socket.connect(target.host, target.port);
    final channel = SecureChannel(socket, target.key);
    final offer = Offer(
      randomId(),
      'file.bin',
      3,
      sha256.convert([1, 2, 3]).toString(),
    );
    await channel.send(offer.toJson(), 'nexodrop-v1-offer');
    await channel.receive('${offer.id}:answer');
    await channel.send({'data': 'AQID'}, '${offer.id}:data:1');
    await finished.future;
    channel.close();
    expect(received, isNull);
    expect(await destination.list().toList(), isEmpty);
  });

  test('Dos archivos del mismo nombre no se sobreescriben', () async {
    final target = await start();
    final file = await File('${temp.path}/same.txt').writeAsString('primero');
    await sender.send(file, target, (_, _) {}, statuses.add);
    await finished.future;
    final first = received!;
    finished = Completer<void>();
    await file.writeAsString('segundo');
    await sender.send(file, target, (_, _) {}, statuses.add);
    await finished.future;
    expect(received!.path, isNot(first.path));
    expect(await first.readAsString(), 'primero');
    expect(await received!.readAsString(), 'segundo');
  });

  test(
    'Solo confirma el envío después de guardar en el destino final',
    () async {
      final saving = Completer<void>();
      final saved = Completer<void>();
      final target = await start(
        saveReceived: (file) async {
          saving.complete();
          await saved.future;
          return 'Descargas/NexoDrop/${file.uri.pathSegments.last}';
        },
      );
      final file = await File('${temp.path}/save.txt').writeAsString('datos');
      var acknowledged = false;
      final sending = sender
          .send(file, target, (_, _) {}, statuses.add)
          .then((_) => acknowledged = true);
      await saving.future;
      expect(acknowledged, isFalse);
      saved.complete();
      await sending;
      await finished.future;
      expect(acknowledged, isTrue);
    },
  );

  test(
    'Un fallo del guardado público no confirma el envío ni borra la copia verificada',
    () async {
      final target = await start(
        saveReceived: (_) async =>
            throw const FileSystemException('Sin espacio'),
      );
      final file = await File('${temp.path}/save.txt').writeAsString('datos');
      await expectLater(
        sender.send(file, target, (_, _) {}, statuses.add),
        throwsA(anything),
      );
      await finished.future;
      expect(
        await File('${destination.path}/save.txt').readAsString(),
        'datos',
      );
      expect(received, isNull);
      expect(
        statuses.any((s) => s.startsWith('Enviado y verificado')),
        isFalse,
      );
    },
  );

  test('El nombre no puede escapar de la carpeta de destino', () {
    expect(safeName('../../privado.txt'), 'privado.txt');
    expect(safeName(r'C:\test\file.txt'), 'file.txt');
    expect(safeName('..'), 'archivo');
  });
}
