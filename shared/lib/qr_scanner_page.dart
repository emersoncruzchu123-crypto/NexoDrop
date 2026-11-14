import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pairing_qr.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission || _returned) return;
    if (state == AppLifecycleState.resumed &&
        !_controller.value.isRunning &&
        !_controller.value.isStarting) {
      unawaited(_controller.start());
    } else if (state == AppLifecycleState.inactive) {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  bool _returned = false;
  String? _error;

  void _detected(BarcodeCapture capture) {
    if (_returned || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (barcode.format != BarcodeFormat.qrCode || value == null) continue;
      try {
        final pairing = parsePairingQr(value);
        _returned = true;
        Navigator.of(context).pop(pairing.code);
        return;
      } on FormatException {
        if (_error == null) {
          setState(
            () => _error =
                'Ese QR no es de NexoDrop. Escanea el que muestra el receptor.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Apunta al QR del apartado Wi-Fi / red local '
            'en el otro dispositivo.',
          ),
        ),
        Expanded(
          child: ClipRect(
            child: MobileScanner(
              // This page owns the camera and releases it when the route closes.
              controller: _controller,
              onDetect: _detected,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Permite el acceso a la cámara para escanear. Si lo bloqueaste, '
                                  'actívalo en Ajustes → Aplicaciones → NexoDrop → Permisos y vuelve a intentarlo.'
                            : 'No se pudo abrir la cámara. Cierra otras aplicaciones que la usen y vuelve a intentarlo.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Conecta una vez. Después podrás elegir Enviar o Recibir.',
          ),
        ),
      ],
    ),
  );
}
