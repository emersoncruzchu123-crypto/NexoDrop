import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/history_file_tile.dart';
import 'package:nexodrop_shared/receive_history.dart';

void main() {
  testWidgets('El historial muestra tamaño real, fecha y acción abrir', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nexodrop-history-ui-'),
    ))!;
    addTearDown(() => directory.delete(recursive: true));
    final file = (await tester.runAsync(
      () =>
          File('${directory.path}/foto.png').writeAsBytes(List.filled(2048, 0)),
    ))!;
    final entry = ReceivedEntry(
      id: file.path,
      name: 'foto.png',
      location: file.path,
      date: DateTime(2026, 11, 14, 10, 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HistoryFileTile(entry: entry)),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('2.0 KB · 14/11/2026 10:30'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byTooltip('Abrir archivo'), findsOneWidget);
    expect(await tester.runAsync(() => file.length()), 2048);
  });
}
