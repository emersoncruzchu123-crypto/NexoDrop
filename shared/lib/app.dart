import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'pairing_qr.dart';
import 'qr_scanner_page.dart';
import 'session.dart';
import 'transfer.dart';
import 'received_files.dart';
import 'receive_history.dart';
import 'connection_background.dart';
import 'file_selection.dart';
import 'history_file_tile.dart';

const _accent = Color(0xff6fe7c5);
const _panel = Color(0xff171f1d);
const _muted = Color(0xffa8b8b2);

class NexoDropApp extends StatelessWidget {
  const NexoDropApp({super.key, this.autoStart = true});
  final bool autoStart;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NexoDrop',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff0a0f0e),
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        onPrimary: Color(0xff00382c),
        surface: _panel,
        onSurface: Color(0xffffffff),
        secondary: _accent,
        outline: Color(0xff34453d),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff0a0f0e),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xff2a3532)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff090e0b),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? _accent : _muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? _accent : _muted,
          ),
        ),
        backgroundColor: _panel,
        indicatorColor: Color(0xff22463b),
      ),
    ),
    home: TransferPage(autoStart: autoStart),
  );
}

String formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class TransferPage extends StatefulWidget {
  const TransferPage({super.key, this.autoStart = true});
  final bool autoStart;
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  int _tab = 0;
  static const _labels = ['Wi-Fi', 'Detalles'];
  static const _icons = [Icons.wifi_rounded, Icons.info_outline_rounded];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 850;
      final content = IndexedStack(
        index: _tab,
        children: [
          WifiPage(autoStart: widget.autoStart),
          const _InformationPage(),
        ],
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'NexoDrop',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                '1.0 • EN PROGRESO',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    extended: true,
                    minExtendedWidth: 220,
                    backgroundColor: const Color(0xff0a0f0e),
                    indicatorColor: const Color(0xff22463b),
                    selectedIndex: _tab,
                    onDestinationSelected: (value) =>
                        setState(() => _tab = value),
                    destinations: [
                      for (var i = 0; i < _labels.length; i++)
                        NavigationRailDestination(
                          icon: Icon(_icons[i]),
                          label: Text(_labels[i]),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1, color: Color(0xff2a3532)),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      label: _labels[i],
                    ),
                ],
              ),
      );
    },
  );
}

class _InformationPage extends StatelessWidget {
  const _InformationPage();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Text(
        'Detalles',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 24),
      const _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image(
              image: AssetImage(
                'assets/branding/logo.png',
                package: 'nexodrop_shared',
              ),
              width: 64,
              height: 64,
              semanticLabel: 'Logo de NexoDrop',
            ),
            SizedBox(height: 24),
            Text('Desarrollado por', style: TextStyle(color: _muted)),
            SizedBox(height: 6),
            Text(
              'EMERSON CRUZ CHUQUIPOMA',
              style: TextStyle(
                fontSize: 14,
                color: _muted,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 24),
            Text('Versión 1.0 · En progreso'),
            SizedBox(height: 24),
            Text('Créditos', style: TextStyle(color: _muted)),
            SizedBox(height: 6),
            Text('Codex', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: Border(),
          collapsedShape: Border(),
          leading: Icon(Icons.description_outlined, color: _accent),
          title: Text('Términos de uso', style: TextStyle(fontSize: 15)),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'NexoDrop no recopila información personal ni envía tus archivos a servidores externos. '
                'Las transferencias son privadas, cifradas y directas entre los dispositivos que vinculas en tu red local.\n\n'
                'Los archivos recibidos y el historial se guardan en tu dispositivo. Borrar el historial no elimina los archivos. '
                'Comparte tu QR solo con personas de confianza y acepta únicamente las transferencias que reconozcas.\n\n'
                'NexoDrop es un proyecto de código abierto bajo la licencia GNU GPLv3. '
                'Está en desarrollo. Comparte únicamente archivos que tengas derecho a enviar.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
            ),
            TextButton(
              onPressed: () async {
                final license = await rootBundle.loadString(
                  'packages/nexodrop_shared/assets/licenses/GPL-3.0.txt',
                );
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('GNU GPLv3'),
                    content: SizedBox(
                      width: 640,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          license,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Ver licencia GPLv3'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class WifiPage extends StatefulWidget {
  const WifiPage({super.key, required this.autoStart});
  final bool autoStart;
  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  TransferService _files = TransferService();
  final _session = PeerSession();
  final _background = ConnectionBackground();
  final _manual = TextEditingController();
  final _watch = Stopwatch();
  ReceiveHistory? _history;
  ReceivedFileSaver? _saver;
  bool _clearingHistory = false;
  int _sentCount = 0;
  List<ReceivedEntry> get _received => _history?.entries ?? [];
  Directory? _directory;
  final _selection = FileSelection();
  File? get _file => _selection.file;
  bool _starting = false;
  bool _busy = false;
  bool _wasConnected = false;
  bool _hasProgress = false;
  bool _completed = false;
  String _status = 'Conecta tus dispositivos para comenzar.';
  int _done = 0, _total = 0, _lastUpdate = 0;
  BuildContext? _acceptContext;

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
    _selection.addListener(_selectionChanged);
    if (widget.autoStart) unawaited(_prepare());
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (!mounted) return;
    final lost = _wasConnected && !_session.connected;
    if (_wasConnected != _session.connected) {
      unawaited(_updateBackground(_session.connected));
    }
    if (!_wasConnected && _session.connected) {
      _status = 'Elige Enviar o Recibir. No necesitas volver a escanear.';
    }
    _wasConnected = _session.connected;
    if (lost) {
      _files.cancel();
      final dialog = _acceptContext;
      if (dialog != null && dialog.mounted) Navigator.of(dialog).pop(false);
      _status = 'Conexión cerrada. Escanea el nuevo QR para volver a conectar.';
      unawaited(_prepare());
    }
    setState(() {});
  }

  Future<void> _updateBackground(bool connected) async {
    try {
      await _background.update(connected);
    } catch (_) {
      _setStatus(
        'Android no pudo mantener la sesión en segundo plano. Vuelve a NexoDrop e inténtalo de nuevo.',
      );
    }
  }

  Future<void> _prepare() async {
    if (_starting || !mounted) return;
    setState(() => _starting = true);
    try {
      await _session.disconnect();
      await _files.stop();
      _files = TransferService();
      if (_directory == null) {
        final Directory base;
        if (Platform.isAndroid) {
          base = await getApplicationDocumentsDirectory();
        } else {
          base =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
        final support = await getApplicationSupportDirectory();
        final history = ReceiveHistory(
          File('${support.path}/received-history.json'),
        );
        await history.load();
        _history = history;
        _saver = ReceivedFileSaver(history: history);
        final directory = Directory('${base.path}/NexoDrop');
        await migrateReceivedFiles(
          directory,
          legacy: Platform.isAndroid
              ? Directory('${base.path}/Recibidos')
              : null,
        );
        _directory = directory;
        final importExisting = !history.existed;
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is File &&
              !isTransferPartial(entry.uri.pathSegments.last)) {
            if (Platform.isAndroid || importExisting) await _saver!.save(entry);
          }
        }
        if (!history.existed) await history.clear();
      }
      if (!mounted) return;
      await _files.listen(
        directory: _directory!,
        accept: _accept,
        progress: _progress,
        status: _setStatus,
        finished: _finish,
        authorize: (id) =>
            _session.connected &&
            id == _session.id &&
            _session.mode == TransferMode.receive,
        saveReceived: _saveReceived,
      );
      await _session.start(_files.addresses);
      if (!mounted) {
        await _files.stop();
        return;
      }
    } catch (error) {
      _setStatus('No se pudo preparar la conexión: $error');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _session.removeListener(_sessionChanged);
    _session.dispose();
    unawaited(_background.update(false).catchError((Object _) {}));
    unawaited(_files.stop());
    _manual.dispose();
    super.dispose();
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() {
      _status = value;
      if (value.startsWith('Enviado y verificado')) _sentCount++;
      if (value.startsWith('Enviado y verificado') ||
          value.startsWith('Recibido y verificado')) {
        _completed = true;
      }
    });
  }

  void _begin() {
    _watch
      ..stop()
      ..reset();
    _lastUpdate = 0;
    setState(() {
      _busy = true;
      _hasProgress = false;
      _completed = false;
      _done = 0;
      _total = 0;
    });
    _session.setBusy(true);
  }

  void _finish() {
    _watch.stop();
    if (!mounted) return;
    setState(() => _busy = false);
    _session.setBusy(false);
  }

  void _progress(int done, int total) {
    if (!_watch.isRunning) _watch.start();
    if (done != 0 &&
        done != total &&
        _watch.elapsedMilliseconds - _lastUpdate < 100) {
      return;
    }
    _lastUpdate = _watch.elapsedMilliseconds;
    if (mounted) {
      setState(() {
        _hasProgress = true;
        _done = done;
        _total = total;
        _status = 'Transfiriendo archivo…';
      });
    }
  }

  Future<bool> _accept(Offer offer) async {
    if (!mounted ||
        !_session.connected ||
        _session.mode != TransferMode.receive) {
      return false;
    }
    _begin();
    Timer? timer;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _acceptContext = context;
        timer ??= Timer(const Duration(seconds: 55), () {
          if (context.mounted) Navigator.pop(context, false);
        });
        return AlertDialog(
          title: const Text('¿Recibir este archivo?'),
          content: Text('${offer.name}\n${formatBytes(offer.size)}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Rechazar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Recibir'),
            ),
          ],
        );
      },
    );
    timer?.cancel();
    _acceptContext = null;
    return accepted ?? false;
  }

  Future<void> _connect(String code) async {
    try {
      await _session.connect(parsePairingQr(code));
      _setStatus('Elige Enviar o Recibir. No necesitas volver a escanear.');
    } on FormatException {
      _setStatus(
        'El enlace no es válido. Copia el enlace completo o escanea el QR.',
      );
    } catch (_) {
      _setStatus(_session.status);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (mounted && code != null) await _connect(code);
  }

  Future<void> _pick() async {
    try {
      if (_session.connected) await _background.update(true);
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path != null && mounted) _selection.select(File(path));
    } catch (error) {
      _setStatus('No se pudo seleccionar: $error');
    }
  }

  Future<void> _send() async {
    final peer = _session.peer;
    final id = _session.id;
    if (_file == null ||
        peer == null ||
        id == null ||
        _session.mode != TransferMode.send ||
        _session.busy) {
      return;
    }
    _begin();
    try {
      await _selection.send((file) async {
        await _session.ensureReachable();
        await _files.send(file, peer, _progress, _setStatus, sessionId: id);
      });
    } catch (error) {
      _setStatus('No se completó el envío: $error');
    } finally {
      _finish();
    }
  }

  Future<String> _saveReceived(File file) async {
    final location = await _saver!.save(file);
    if (mounted) setState(() {});
    return location;
  }

  Future<void> _clearHistory() async {
    if (_history == null || _clearingHistory) return;
    setState(() => _clearingHistory = true);
    try {
      await _history!.clear();
      if (mounted) {
        setState(
          () => _status =
              'Historial borrado. Los archivos siguen guardados en NexoDrop.',
        );
      }
    } catch (error) {
      _setStatus('No se pudo borrar el historial: $error');
    } finally {
      if (mounted) setState(() => _clearingHistory = false);
    }
  }

  Widget _title(String text, {double size = 24}) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  );

  Widget _connectPanel(bool disabled) => Container(
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _accent.withValues(alpha: 0.6)),
    ),
    padding: const EdgeInsets.all(12),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.link_rounded, color: _accent, size: 25),
                const SizedBox(height: 6),
                _title('Conectar dispositivo', size: 17),
                const SizedBox(height: 10),
                if (_session.addresses.isEmpty)
                  FilledButton.icon(
                    onPressed: disabled ? null : _prepare,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Preparar conexión',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                else if (defaultTargetPlatform == TargetPlatform.android)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: disabled || _session.addresses.isEmpty
                        ? null
                        : _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Escanear QR'),
                  )
                else
                  const Text(
                    'Escanea tu QR desde el celular',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 7),
                Text(
                  defaultTargetPlatform == TargetPlatform.android
                      ? 'Para computadora u otro Android'
                      : 'Abre NexoDrop y pulsa Escanear QR',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (_starting)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 22, color: Color(0xff2a3532)),
          Expanded(
            child: Center(
              child: _session.addresses.isEmpty
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_rounded, size: 72, color: _muted),
                        SizedBox(height: 8),
                        Text(
                          'Tu QR aparecerá al preparar la conexión',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    )
                  : PairingQrCard(addresses: _session.addresses, compact: true),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _manualConnection(bool disabled) => Material(
    color: _panel,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      dense: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      title: const Text(
        'Conexión manual (opcional)',
        style: TextStyle(fontSize: 13, color: _muted),
      ),
      children: [
        for (final address in _session.addresses)
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  'IP: ${address.host}  ·  Puerto: ${address.port}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Copiar enlace',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address.code));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace copiado.')),
                    );
                  }
                },
              ),
            ],
          ),
        const Text(
          'Copia el enlace completo: incluye la clave de conexión.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _manual,
          enabled: !disabled,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Enlace del otro dispositivo',
            hintText: 'nexodrop://…',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: disabled || _session.addresses.isEmpty
              ? null
              : () => _connect(_manual.text),
          child: const Text('Conectar'),
        ),
      ],
    ),
  );

  Widget _role(
    TransferMode value,
    IconData icon,
    String title,
    String description,
  ) {
    final selected = _session.mode == value;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? const Color(0xff15372b) : _panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _session.busy || _busy ? null : () => _session.choose(value),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? _accent : const Color(0xff34453d),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: selected ? _accent : _muted, size: 24),
                const SizedBox(height: 8),
                _title(title, size: 18),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: _muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectedPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _accent, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title('Dispositivo conectado', size: 20),
                  Text(
                    _session.peer!.host,
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Desconectar',
              onPressed: _busy || _session.busy
                  ? null
                  : () => _session.disconnect(),
              icon: const Icon(Icons.link_off_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _role(
              TransferMode.send,
              Icons.north_east_rounded,
              'Enviar',
              'Elige un archivo',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _role(
              TransferMode.receive,
              Icons.south_west_rounded,
              'Recibir',
              'Espera el archivo',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_session.mode == null)
        const Text(
          'Elige una opción. El otro dispositivo adoptará el rol complementario.',
          style: TextStyle(color: _muted),
        ),
      if (_session.mode == TransferMode.send)
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Prepara tu envío', size: 18),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy || _session.busy ? null : _pick,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Seleccionar archivo'),
              ),
              if (_file != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        color: _accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_file!.uri.pathSegments.last)),
                      IconButton(
                        tooltip: 'Quitar selección',
                        onPressed: _busy || _session.busy
                            ? null
                            : () => _selection.clear(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _file == null || _busy || _session.busy
                    ? null
                    : _send,
                icon: const Icon(Icons.arrow_upward_rounded),
                label: const Text('Enviar archivo'),
              ),
            ],
          ),
        ),
      if (_session.mode == TransferMode.receive)
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.downloading_rounded, color: _accent, size: 24),
              const SizedBox(height: 8),
              _title(
                _busy ? 'Recibiendo archivo' : 'Esperando un archivo',
                size: 18,
              ),
              const SizedBox(height: 8),
              const Text(
                'El otro dispositivo puede seleccionar y enviar. Tú confirmas la recepción.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              SelectableText(
                'Guardado automático: ${Platform.isAndroid ? 'Descargas/NexoDrop' : _directory?.path ?? ''}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _activity() {
    final seconds = _watch.elapsedMilliseconds / 1000;
    final fraction = _total > 0
        ? (_done / _total).clamp(0.0, 1.0)
        : _completed
        ? 1.0
        : 0.0;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _completed
                        ? Icons.verified_outlined
                        : Icons.swap_vert_rounded,
                    color: _accent,
                  ),
                  const SizedBox(width: 10),
                  _title('Actividad', size: 18),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff17392e),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: _accent, size: 6),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _busy
                            ? 'Transferencia en curso'
                            : _session.connected
                            ? 'Dispositivo conectado'
                            : _session.addresses.isEmpty
                            ? 'Preparando conexión'
                            : 'Listo para compartir',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stat(
                  Icons.south_rounded,
                  'Recibidos: ${_received.length} archivos',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: 'Enviados desde que abriste la app',
                  child: _stat(
                    Icons.north_rounded,
                    'Enviados: $_sentCount archivos',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _status == 'Conecta tus dispositivos para comenzar.' &&
                    !_session.connected
                ? 'Cuando conectes un dispositivo, aquí verás la actividad.'
                : _status,
            key: const Key('status'),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          if (_hasProgress || _busy) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(fraction * 100).toStringAsFixed(0)} %',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${formatBytes(seconds > 0 ? _done / seconds : 0)}/s',
                  style: const TextStyle(color: _accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _hasProgress ? fraction : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatBytes(_done)} / ${formatBytes(_total)}',
              style: const TextStyle(color: _muted),
            ),
          ],
          if (_busy)
            TextButton.icon(
              onPressed: () {
                _files.cancel();
                final dialog = _acceptContext;
                if (dialog != null && dialog.mounted) {
                  Navigator.pop(dialog, false);
                }
                _setStatus('Cancelando transferencia…');
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar transferencia'),
            ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xff0f1714),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: _accent, size: 16),
        const SizedBox(width: 5),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
      ],
    ),
  );

  Widget _historyPanel() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _title('Historial de recibidos', size: 15)),
            Tooltip(
              message: 'Borra el historial sin eliminar los archivos',
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(48, 40),
                ),
                onPressed:
                    _received.isEmpty || _busy || _starting || _clearingHistory
                    ? null
                    : _clearHistory,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text(
                  'Borrar todo',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        if (_received.isEmpty) ...[
          const Icon(Icons.folder_outlined, color: _accent, size: 29),
          const SizedBox(height: 5),
          const Text(
            'Aún no hay archivos recibidos',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 5),
          const Text(
            'Los archivos que recibas aparecerán aquí y se guardarán automáticamente en NexoDrop.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ] else ...[
          const Text(
            'Borrar el historial no elimina los archivos.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          SizedBox(
            height: 156,
            child: ListView.builder(
              primary: false,
              itemCount: _received.length,
              itemBuilder: (context, index) => HistoryFileTile(
                entry: _received[_received.length - 1 - index],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final disabled = _starting || _session.connecting || _busy;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              key: const Key('wifi-dashboard'),
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                8,
                wide ? 28 : 16,
                12,
              ),
              children: [
                const Text(
                  'CERCA DE TI • Wi-Fi / red local',
                  style: TextStyle(
                    color: _accent,
                    letterSpacing: 1.2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                _title('Comparte archivos sin internet', size: 32),
                const SizedBox(height: 4),
                const Text(
                  'Tus archivos. Tus dispositivos. En la misma red Wi-Fi.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_session.connected)
                  _connectedPanel()
                else ...[
                  _connectPanel(disabled),
                  const SizedBox(height: 8),
                  _manualConnection(disabled),
                ],
                if (_session.connecting) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _activity()),
                      const SizedBox(width: 12),
                      Expanded(child: _historyPanel()),
                    ],
                  )
                else ...[
                  _activity(),
                  const SizedBox(height: 10),
                  _historyPanel(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
