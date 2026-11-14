import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/app.dart';

void main() {
  testWidgets('Muestra la conexión y los dos apartados', (tester) async {
    await tester.pumpWidget(const NexoDropApp(autoStart: false));
    expect(find.text('NexoDrop'), findsOneWidget);
    expect(find.text('Comparte archivos sin internet'), findsOneWidget);
    expect(find.text('Bluetooth'), findsNothing);
    expect(find.text('Cable'), findsNothing);
    expect(find.text('Detalles'), findsWidgets);
    expect(find.text('Preparar conexión'), findsOneWidget);
  });
}
