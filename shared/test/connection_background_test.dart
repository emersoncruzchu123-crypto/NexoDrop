import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexodrop_shared/connection_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.nexodrop/connection');
  final calls = <bool>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add((call.arguments as Map)['connected'] as bool);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Inicia una vez, conserva orden y detiene al desconectar', () async {
    final service = ConnectionBackground(enabled: true);
    await Future.wait([
      service.update(true),
      service.update(true),
      service.update(false),
    ]);
    expect(calls, [true, false]);
  });

  test('Linux no intenta activar un servicio Android', () async {
    final service = ConnectionBackground(enabled: false);
    await service.update(true);
    await service.update(false);
    expect(calls, isEmpty);
  });
}
