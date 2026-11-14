import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/file_selection.dart';

void main() {
  late FileSelection selection;
  setUp(() {
    selection = FileSelection();
  });
  tearDown(() {
    selection.dispose();
  });

  test(
    'Un envío confirmado limpia la selección y no puede repetirse',
    () async {
      selection.select(File('/archivo.txt'));
      var sends = 0;
      await selection.send((file) async {
        sends++;
      });
      expect(selection.file, isNull);
      await expectLater(
        selection.send((_) async {
          sends++;
        }),
        throwsStateError,
      );
      expect(sends, 1);
    },
  );

  test(
    'Fallo o cancelación conserva el archivo para reintentar o quitarlo',
    () async {
      final file = File('/archivo.txt');
      selection.select(file);
      await expectLater(
        selection.send((_) async {
          throw const SocketException('cancelado');
        }),
        throwsA(isA<SocketException>()),
      );
      expect(selection.file, file);
      expect(selection.sending, isFalse);
      await selection.send((_) async {});
      expect(selection.file, isNull);
    },
  );

  test('Quitar la selección no borra el archivo original', () async {
    final temp = await Directory.systemTemp.createTemp('nexodrop-selection-');
    try {
      final file = await File(
        '${temp.path}/original',
      ).writeAsString('conservar');
      selection.select(file);
      expect(selection.clear(), isTrue);
      expect(selection.file, isNull);
      expect(await file.readAsString(), 'conservar');
    } finally {
      await temp.delete(recursive: true);
    }
  });

  test('No cambia ni repite una selección durante un envío activo', () async {
    selection.select(File('/primero'));
    final complete = Completer<void>();
    final sending = selection.send((_) => complete.future);
    expect(selection.clear(), isFalse);
    expect(() => selection.select(File('/otro')), throwsStateError);
    await expectLater(selection.send((_) async {}), throwsStateError);
    complete.complete();
    await sending;
    expect(selection.file, isNull);
  });
}
