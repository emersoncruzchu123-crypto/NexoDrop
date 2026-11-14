import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/app.dart';
import 'package:nexodrop_shared/transfer_utils.dart';

void main() {
  testWidgets(
    'Windows: nombres compatibles y misma interfaz de escritorio',
    (tester) async {
      for (final name in [
        'CON',
        'nul.txt',
        'AUX.zip',
        'COM1.mp4',
        'LPT9',
        'COM¹.txt',
        'CONOUT\$',
        'CON .txt',
      ]) {
        expect(safeName(name, windows: true), startsWith('_'), reason: name);
      }
      expect(safeName('COM10.txt', windows: true), 'COM10.txt');
      expect(safeName('foto de Cruz.png', windows: true), 'foto de Cruz.png');
      expect(safeName('informe:2026?.txt', windows: true), 'informe_2026_.txt');
      expect(safeName('carpeta\\NUL.txt', windows: true), '_NUL.txt');
      expect(safeName('a' * 119 + '.otra', windows: true), 'a' * 119);
      expect(
        safeName('CON.txt'),
        'CON.txt',
      ); // Other platforms keep existing behavior.
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const NexoDropApp(autoStart: false));
      expect(find.text('Comparte archivos sin internet'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      await tester.tap(find.text('Detalles').last);
      await tester.pumpAndSettle();
      expect(find.text('Codex'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Términos de uso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
