import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/received_files.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('nexodrop-storage-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'Publica directamente y conserva los archivos con el mismo nombre',
    () async {
      final first = await File(
        '${root.path}/foto.jpg',
      ).writeAsString('original');
      final partial = await createTransferPartial(root);
      await partial.writeAsString('nuevo');
      final saved = await publishReceivedFile(partial, root, 'foto.jpg');
      expect(saved.parent.path, root.path);
      expect(saved.uri.pathSegments.last, 'foto (1).jpg');
      expect(await first.readAsString(), 'original');
      expect(await saved.readAsString(), 'nuevo');
      expect((await root.list().toList()).whereType<Directory>(), isEmpty);
    },
  );

  test('No sobrescribe directorios ni enlaces simbólicos', () async {
    await Directory('${root.path}/dato').create();
    final external = await File(
      '${root.path}/original',
    ).writeAsString('conservar');
    await Link('${root.path}/dato (1)').create(external.path);
    final partial = await createTransferPartial(root);
    await partial.writeAsString('nuevo');
    final saved = await publishReceivedFile(partial, root, 'dato');
    expect(saved.uri.pathSegments.last, 'dato (2)');
    expect(await external.readAsString(), 'conservar');
  });

  test(
    'Migra carpetas antiguas y Recibidos sin perder archivos ni duplicados',
    () async {
      final destination = await Directory('${root.path}/NexoDrop').create();
      final legacy = await Directory('${root.path}/Recibidos').create();
      final old = await Directory(
        '${destination.path}/NexoDrop-ab1234',
      ).create();
      await File('${destination.path}/documento.txt').writeAsString('primero');
      await File('${old.path}/documento.txt').writeAsString('segundo');
      await File('${legacy.path}/foto.jpg').writeAsString('foto');
      final unrelated = await Directory(
        '${destination.path}/Personal',
      ).create();
      await File('${unrelated.path}/conservar').writeAsString('sin tocar');
      await migrateReceivedFiles(destination, legacy: legacy);
      expect(
        await File('${destination.path}/documento.txt').readAsString(),
        'primero',
      );
      expect(
        await File('${destination.path}/documento (1).txt').readAsString(),
        'segundo',
      );
      expect(await File('${destination.path}/foto.jpg').readAsString(), 'foto');
      expect(await old.exists(), isFalse);
      expect(await legacy.exists(), isFalse);
      expect(
        await File('${unrelated.path}/conservar').readAsString(),
        'sin tocar',
      );
      await migrateReceivedFiles(destination, legacy: legacy);
      expect((await destination.list().toList()).whereType<File>().length, 3);
    },
  );

  test(
    'Los parciales antiguos nunca aparecen como archivos completos',
    () async {
      final old = await Directory('${root.path}/NexoDrop-ab1234').create();
      await File('${old.path}/archivo.part').writeAsString('incompleto');
      await migrateReceivedFiles(root);
      expect(await File('${root.path}/archivo.part').exists(), isFalse);
      expect(await File('${old.path}/archivo.part').exists(), isTrue);
    },
  );
}
