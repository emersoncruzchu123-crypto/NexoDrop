import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart' as zxing;
import 'package:nexodrop_shared/pairing_qr.dart';
import 'package:nexodrop_shared/qr_scanner_page.dart';
import 'package:nexodrop_shared/transfer.dart';

class FakeCamera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  bool denied = false;
  bool stopped = false;
  bool disposed = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  void scan(String value) => captures.add(
    BarcodeCapture(
      barcodes: [Barcode(rawValue: value, format: BarcodeFormat.qrCode)],
    ),
  );
}

Future<String> decodeDisplayedQr(WidgetTester tester) async {
  final painter = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(QrImageView).last,
          matching: find.byType(CustomPaint),
        ),
      )
      .map((widget) => widget.painter)
      .whereType<QrPainter>()
      .single;
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.translate(20, 20);
    painter.paint(canvas, const Size(256, 256));
    final picture = recorder.endRecording();
    final image = await picture.toImage(296, 296);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    final pixels = Int32List(296 * 296);
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] =
          (bytes[i * 4] << 16) | (bytes[i * 4 + 1] << 8) | bytes[i * 4 + 2];
    }
    image.dispose();
    picture.dispose();
    return zxing.QRCodeReader()
        .decode(
          zxing.BinaryBitmap(
            zxing.HybridBinarizer(zxing.RGBLuminanceSource(296, 296, pixels)),
          ),
        )
        .text;
  }))!;
}

void main() {
  final first = Pairing('192.168.1.20', 45873, List.generate(32, (i) => i));
  final second = Pairing(
    '192.168.43.10',
    45873,
    List.generate(32, (i) => 31 - i),
  );

  test('El contenido del QR conserva dirección, puerto y clave completa', () {
    final result = parsePairingQr(first.code);
    expect(result.host, first.host);
    expect(result.port, first.port);
    expect(result.key, first.key);
    for (final invalid in [
      'https://example.com',
      'texto',
      'nexodrop://host:45873/#AAAA',
      'x' * 1025,
    ]) {
      expect(() => parsePairingQr(invalid), throwsFormatException);
    }
  });

  testWidgets('QR cambia con la red y mantiene oculto el enlace largo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PairingQrCard(addresses: [first, second]),
          ),
        ),
      ),
    );
    expect(await decodeDisplayedQr(tester), first.code);
    expect(find.text(first.code), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red: ${second.host}').last);
    await tester.pumpAndSettle();
    expect(await decodeDisplayedQr(tester), second.code);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR compacto abre un código ampliado válido y permite cerrar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PairingQrCard(addresses: [first], compact: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(await decodeDisplayedQr(tester), first.code);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(await decodeDisplayedQr(tester), first.code);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El QR cabe en una pantalla estrecha', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(44),
              child: PairingQrCard(addresses: [first]),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('Escáner', () {
    late FakeCamera camera;
    late MobileScannerPlatform previous;
    setUp(() {
      previous = MobileScannerPlatform.instance;
      camera = FakeCamera();
      MobileScannerPlatform.instance = camera;
    });
    tearDown(() async {
      MobileScannerPlatform.instance = previous;
      await camera.captures.close();
    });

    testWidgets(
      'Ignora QR ajeno, devuelve uno válido una sola vez y libera cámara',
      (tester) async {
        String? result;
        var returns = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(builder: (_) => const QrScannerPage()),
                    );
                    returns++;
                  },
                  child: const Text('Abrir cámara'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir cámara'));
        await tester.pumpAndSettle();
        camera.scan('https://example.com');
        await tester.pumpAndSettle();
        expect(find.textContaining('Ese QR no es de NexoDrop'), findsOneWidget);
        expect(result, isNull);
        camera.scan(first.code);
        camera.scan(first.code);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(result, first.code);
        expect(returns, 1);
        await tester.pump();
        expect(find.byType(QrScannerPage), findsNothing);
        expect(find.byType(QrScannerPage, skipOffstage: false), findsNothing);
        expect(camera.stopped || camera.disposed, isTrue);
        expect(find.text('Abrir cámara'), findsOneWidget);
      },
    );

    testWidgets('Permiso denegado muestra instrucciones y permite volver', (
      tester,
    ) async {
      camera.denied = true;
      await tester.pumpWidget(const MaterialApp(home: QrScannerPage()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Permite el acceso a la cámara'),
        findsOneWidget,
      );
      expect(find.text('Volver'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}
