import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/app.dart';

void main() {
  setUpAll(() async {
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File(
            '$fonts/${entry.value}',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'Dashboard sin desbordes $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const RepaintBoundary(
            key: Key('preview'),
            child: NexoDropApp(autoStart: false),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Comparte archivos sin internet'), findsOneWidget);
        expect(find.text('Conexión manual (opcional)'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        // Normal screens keep the empty history in view; smaller screens may scroll.
        if (size.width >= 390) {
          final history = tester.getRect(
            find.text(
              'Los archivos que recibas aparecerán aquí y se guardarán automáticamente en NexoDrop.',
            ),
          );
          final bottom = size.width < 850
              ? tester.getTopLeft(find.byType(NavigationBar)).dy
              : size.height;
          expect(history.bottom, lessThan(bottom));
        }
        if (const bool.fromEnvironment('CAPTURE_DASHBOARD')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/nexodrop-dashboard-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Conexión manual (opcional)'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        size.width < 500 ? TargetPlatform.android : TargetPlatform.linux,
      }),
    );
  }
}
