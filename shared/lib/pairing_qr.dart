import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'transfer.dart';

/// QR payloads are connection data only; they are never opened as web links.
Pairing parsePairingQr(String value) {
  if (value.length > 1024) {
    throw const FormatException('El QR no es un código de NexoDrop válido.');
  }
  return Pairing.parse(value);
}

class PairingQrCard extends StatefulWidget {
  const PairingQrCard({
    super.key,
    required this.addresses,
    this.compact = false,
  });
  final List<Pairing> addresses;
  final bool compact;

  @override
  State<PairingQrCard> createState() => _PairingQrCardState();
}

class _PairingQrCardState extends State<PairingQrCard> {
  String? _selectedHost;

  @override
  Widget build(BuildContext context) {
    if (widget.addresses.isEmpty) return const SizedBox.shrink();
    final pairing = widget.addresses.firstWhere(
      (address) => address.host == _selectedHost,
      orElse: () => widget.addresses.first,
    );
    if (widget.compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Ampliar tu código QR',
            child: InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tu código QR'),
                  content: SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      child: PairingQrCard(addresses: widget.addresses),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 112,
                  child: QrImageView(
                    data: pairing.code,
                    size: 112,
                    padding: const EdgeInsets.all(8),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Tu código QR — ${pairing.host}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 3),
          const Text(
            'Muestra este QR para vincular',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xffa8b8b2), fontSize: 11),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'En el celular, pulsa «Escanear QR» y apunta a este código. '
          'Ambos dispositivos deben estar en la misma red.',
        ),
        if (widget.addresses.length > 1) ...[
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: pairing.host,
            isExpanded: true,
            items: [
              for (final address in widget.addresses)
                DropdownMenuItem(
                  value: address.host,
                  child: Text('Red: ${address.host}'),
                ),
            ],
            onChanged: (host) => setState(() => _selectedHost = host),
          ),
          const Text(
            'Si no conecta, elige la dirección de la red que comparte el celular.',
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AspectRatio(
              aspectRatio: 1,
              child: QrImageView(
                data: pairing.code,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
                semanticsLabel: 'QR privado para conectar con NexoDrop',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Dispositivo: ${pairing.host}'),
        const Text(
          'Comparte el QR solo con el dispositivo que quieras vincular.',
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Conexión manual (opcional)'),
          children: [
            SelectableText(pairing.code),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pairing.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace copiado.')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar enlace'),
            ),
          ],
        ),
      ],
    );
  }
}
