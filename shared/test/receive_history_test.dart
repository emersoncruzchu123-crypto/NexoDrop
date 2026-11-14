import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/receive_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ReceiveHistory history;
  const channel = MethodChannel('app.nexodrop/files');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('nexodrop-history-');
    history = ReceiveHistory(File('${root.path}/metadata/history.json'));
    await history.load();
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'Guardar registra historial; borrarlo persiste y conserva el archivo',
    () async {
      final file = await File(
        '${root.path}/recibido.txt',
      ).writeAsString('conservar');
      await ReceivedFileSaver(history: history, android: false).save(file);
      final reopened = ReceiveHistory(history.file);
      await reopened.load();
      expect(reopened.entries.single.name, 'recibido.txt');
      await reopened.clear();
      await reopened.load();
      expect(reopened.entries, isEmpty);
      expect(await file.readAsString(), 'conservar');
      // Previously saved private leftovers must not repopulate a cleared history.
      await ReceivedFileSaver(history: reopened, android: false).save(file);
      expect(reopened.entries, isEmpty);
      final next = await File('${root.path}/nuevo.txt').writeAsString('nuevo');
      await ReceivedFileSaver(history: reopened, android: false).save(next);
      expect(reopened.entries.single.name, 'nuevo.txt');
    },
  );

  test(
    'Android publica antes de registrar y elimina solo la copia privada',
    () async {
      final private = await File(
        '${root.path}/private.txt',
      ).writeAsString('datos');
      final public = File('${root.path}/public.txt');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveToDownloads');
            expect(history.entries, isEmpty);
            await private.copy(public.path);
            return {
              'id': 'content://downloads/1',
              'name': 'private.txt',
              'location': 'Descargas/NexoDrop/private.txt',
            };
          });
      final location = await ReceivedFileSaver(
        history: history,
        android: true,
      ).save(private);
      expect(location, 'Descargas/NexoDrop/private.txt');
      expect(await private.exists(), isFalse);
      expect(await public.readAsString(), 'datos');
      expect(history.entries.single.id, 'content://downloads/1');
      await history.clear();
      expect(await public.exists(), isTrue);
    },
  );

  test(
    'Si falla guardar en Descargas conserva la copia privada y no registra éxito',
    () async {
      final file = await File(
        '${root.path}/private.txt',
      ).writeAsString('datos');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'disk_full');
          });
      await expectLater(
        ReceivedFileSaver(history: history, android: true).save(file),
        throwsA(isA<PlatformException>()),
      );
      expect(await file.readAsString(), 'datos');
      expect(history.entries, isEmpty);
    },
  );

  test('Si falla persistir el historial no elimina la copia privada', () async {
    final file = await File('${root.path}/private.txt').writeAsString('datos');
    final obstacle = await File(
      '${root.path}/not-a-directory',
    ).writeAsString('obstáculo');
    final broken = ReceiveHistory(File('${obstacle.path}/history.json'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {
            'id': 'content://downloads/1',
            'name': 'private.txt',
            'location': 'Descargas/NexoDrop/private.txt',
          },
        );
    await expectLater(
      ReceivedFileSaver(history: broken, android: true).save(file),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.exists(), isTrue);
    expect(broken.entries, isEmpty);
  });
}
