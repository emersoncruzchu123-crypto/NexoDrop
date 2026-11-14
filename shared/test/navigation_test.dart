import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/app.dart';

void main() {
  testWidgets('Solo Wi-Fi y Detalles con créditos en móvil', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NexoDropApp(autoStart: false));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(WifiPage))).brightness,
      Brightness.dark,
    );
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Bluetooth'), findsNothing);
    expect(find.text('Cable'), findsNothing);
    await tester.tap(find.text('Detalles').last);
    await tester.pumpAndSettle();
    expect(find.text('EMERSON CRUZ CHUQUIPOMA'), findsOneWidget);
    expect(find.text('Versión 1.0 · En progreso'), findsOneWidget);
    expect(find.text('Codex'), findsOneWidget);
    expect(find.textContaining('NexoDrop no recopila'), findsNothing);
    await tester.tap(find.text('Términos de uso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('NexoDrop no recopila'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escritorio muestra navegación lateral sin desbordes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NexoDropApp(autoStart: false));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(2));
    expect(find.text('Bluetooth'), findsNothing);
    expect(find.text('Cable'), findsNothing);
    await tester.tap(find.text('Detalles').last);
    await tester.pumpAndSettle();
    expect(find.text('EMERSON CRUZ CHUQUIPOMA'), findsOneWidget);
    await tester.tap(find.text('Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Preparar conexión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
