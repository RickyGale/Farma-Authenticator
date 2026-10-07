import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../services/activation_service.dart';
import '../services/code_generator.dart';
import '../services/device_identity_service.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/status_led.dart';

class ReverseHomePage extends StatefulWidget {
  const ReverseHomePage({super.key});

  @override
  State<ReverseHomePage> createState() => _ReverseHomePageState();
}

class _ReverseHomePageState extends State<ReverseHomePage>
    with WindowListener, TrayListener {
  final CodeGenerator _codeGenerator = CodeGenerator();
  final ActivationService _activationService = ActivationService();
  final DeviceIdentityService _deviceIdentityService = DeviceIdentityService();
  final TextEditingController _controller = TextEditingController();
  //final FlutterTts _tts = FlutterTts();
  String _generatedUUID = '';
  String _converted = '';
  bool _lAppAttiva = false;
  bool _autoSubmitted = false;
  int diff = 0;
  String _datascadenza = "";
  String _version = "";
  bool _trayInitialized = false;
  // Clipboard watcher
  Timer? _clipboardTimer;
  String? _lastClipboardSeen;
  int? _lastClipboardSeq;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _initUuid() async {
    final uuid = await _deviceIdentityService.getDeviceId();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final datascadenza = prefs.getString("DataScadenza");

    _setStateIfMounted(() {
      _generatedUUID = uuid;

      if (datascadenza != null && datascadenza.isNotEmpty) {
        _datascadenza = DateFormat(
          "dd-MM-yy",
        ).format(DateFormat("dd-MM-yy").parse(datascadenza));
      } else {
        _datascadenza = '';
      }
    });
    // Cambiato: proviamo SEMPRE a registrare e ottenere la data dal server.
    // In caso di errore rete/server, _registerDevice userà in fallback la data memorizzata.
    debugPrint("verifica/registrazione token dal server");
    _registerDevice(uuid);
  }

  Future<void> _initSystemTray() async {
    if (!Platform.isWindows) return;
    final menu = Menu();
    menu.items = [
      MenuItem(key: 'show', label: 'Mostra finestra'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Esci'),
    ];
    // Risolvi l'icona della tray da più posizioni possibili
    final exeDir = File(Platform.resolvedExecutable).parent;
    final iconCandidates = <String>[
      trayIconDefaultPath,
      'assets/tray_icon.ico',
      'assets/tray_icon.png',
      // Tentativi relativi alla cartella dell'eseguibile (build/release)
      '${exeDir.path}\\tray_icon.ico',
      '${exeDir.path}\\assets\\tray_icon.ico',
      '${exeDir.path}\\data\\tray_icon.ico',
      '${exeDir.path}\\data\\flutter_assets\\assets\\tray_icon.ico',
      // Asset inclusi mantenendo il percorso originale nel bundle
      '${exeDir.path}\\data\\flutter_assets\\windows\\runner\\resources\\tray_icon.ico',
      '${exeDir.path}\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico',
      '${exeDir.path}\\app_icon.ico',
    ];
    String? resolvedIcon;
    for (final candidate in iconCandidates) {
      try {
        final file = File(candidate);
        if (await file.exists()) {
          resolvedIcon = file.absolute.path;
          break;
        }
      } catch (_) {}
    }
    bool hadIcon = false;
    if (resolvedIcon != null) {
      await trayManager.setIcon(resolvedIcon);
      hadIcon = true;
    } else {
      debugPrint(
        'Tray icon non trovata. Aggiungi un file .ico (es. assets/tray_icon.ico) e aggiorna pubspec o copia vicino all\'exe.',
      );
    }
    await trayManager.setToolTip('Farma authenticator');
    await trayManager.setContextMenu(menu);
    _trayInitialized = hadIcon;
  }

  Future<void> _showFromTray() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() async {
    await _showFromTray();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (!Platform.isWindows) return;
    switch (menuItem.key) {
      case 'show':
        await _showFromTray();
        break;
      case 'exit':
        _trayInitialized = false;
        await trayManager.destroy();
        await windowManager.setPreventClose(false);
        await windowManager.close();
        break;
    }
  }

  @override
  void onWindowClose() async {
    if (!Platform.isWindows) {
      return;
    }
    final preventClose = await windowManager.isPreventClose();
    if (preventClose) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowEvent(String eventName) {
    if (!Platform.isWindows) {
      return;
    }
    if (eventName == 'minimize') {
      // Nascondi alla tray solo se la tray è attiva, altrimenti lascia l'app minimizzata in taskbar
      if (_trayInitialized) {
        unawaited(windowManager.hide());
      }
    }
  }

  void _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    _setStateIfMounted(() {
      _version = info.version;
    });
  }

  Future<void> _registerDevice(String deviceId) async {
    if (!mounted) return;
    final result = await _activationService.register(
      deviceId: deviceId,
      platform: Theme.of(context).platform.name,
      version: _version,
    );
    _setStateIfMounted(() {
      _lAppAttiva = result.active;
      _datascadenza = result.expiration;
    });
    if (!mounted || result.errorMessage == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _convertiInBase32() async {
    try {
      _setStateIfMounted(() {
        _converted = _codeGenerator.generate(_controller.text);
      });
      // Digitazione automatica globale solo su Windows
      if (Platform.isWindows && _converted.isNotEmpty) {
        await _sendWindowsText(_converted, sendEnter: true);
        // Feedback: SnackBar se visibile, altrimenti notifica di sistema
        try {
          final isVisible = await windowManager.isVisible();
          if (mounted && isVisible) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Codice digitato'),
                  duration: Duration(milliseconds: 900),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          } else {
            // Toast in tray area
            final n = LocalNotification(
              title: 'Farma authenticator',
              body: 'Codice digitato: $_converted',
            );
            await n.show();
          }
        } catch (_) {}
      }
      //_tts.setLanguage('it-IT');
      //_tts.setSpeechRate(0.5); // più lento
      //await _tts.speak( "il codice generato è. " + _converted.split('').join('.'));
      //await _salvaDataScadenza(DateTime.now());
    } catch (e) {
      _setStateIfMounted(() {
        _converted = 'Inserisci un codice valido.';
      });
    }
  }

  Future<void> _sendWindowsText(String text, {bool sendEnter = false}) async {
    if (!Platform.isWindows || text.isEmpty) return;
    await _sendWindowsUnicodeText(text, sendEnter: sendEnter);
  }

  Future<void> _sendWindowsUnicodeText(
    String text, {
    bool sendEnter = false,
  }) async {
    if (!Platform.isWindows || text.isEmpty) return;
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text)) {
      throw ArgumentError('Sono ammessi solo lettere e numeri');
    }

    final inputs = calloc<INPUT>(1);
    try {
      void sendKey(VIRTUAL_KEY key, {bool keyUp = false}) {
        final input = inputs.ref;
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = key;
        input.ki.wScan = 0;
        input.ki.dwFlags = keyUp ? KEYEVENTF_KEYUP : const KEYBD_EVENT_FLAGS(0);
        input.ki.time = 0;
        input.ki.dwExtraInfo = 0;

        final result = SendInput(1, inputs, ffi.sizeOf<INPUT>());
        if (result.value != 1) {
          throw StateError('SendInput fallito: ${result.error}');
        }
      }

      Future<void> pressKey(VIRTUAL_KEY key) async {
        sendKey(key);
        try {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        } finally {
          sendKey(key, keyUp: true);
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }

      for (final unit in text.toUpperCase().codeUnits) {
        await pressKey(VIRTUAL_KEY(unit));
      }
      if (sendEnter) {
        await pressKey(VK_RETURN);
      }
    } finally {
      calloc.free(inputs);
    }
  }

  @override
  void initState() {
    super.initState();
    _getVersion();
    _initUuid();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      // Inizializza la tray e abilita preventClose solo se disponibile
      unawaited(
        _initSystemTray().then((_) async {
          if (_trayInitialized) {
            await windowManager.setPreventClose(true);
          } else {
            await windowManager.setPreventClose(false);
          }
        }),
      );
    }
    _startClipboardWatcher();
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      if (_trayInitialized) {
        unawaited(trayManager.destroy());
      }
    }
    _stopClipboardWatcher();
    _controller.dispose();
    super.dispose();
  }

  void _startClipboardWatcher() {
    if (!Platform.isWindows) {
      return; // abilita solo su Windows (modifica se vuoi)
    }
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _checkClipboardForCode();
    });
  }

  void _stopClipboardWatcher() {
    _clipboardTimer?.cancel();
    _clipboardTimer = null;
  }

  Future<void> _checkClipboardForCode() async {
    try {
      int? seq;
      if (Platform.isWindows) {
        seq = GetClipboardSequenceNumber();
      }
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty) return;
      if (text == _lastClipboardSeen &&
          (seq == null || seq == _lastClipboardSeq)) {
        return;
      }
      // Strict: accetta solo se la clipboard contiene ESATTAMENTE 6 cifre (nessun separatore)
      _lastClipboardSeen = text;
      _lastClipboardSeq = seq;
      final t = text.trim();
      String? code;

      final hashMatch = RegExp(r'^#(\d{6})#$').firstMatch(t);
      if (hashMatch != null) {
        code = hashMatch.group(1);
      }

      if (code == null) return;
      final value = int.tryParse(code);
      if (value == null ||
          value < clipboardCodeMin ||
          value > clipboardCodeMax) {
        return;
      }
      if (!mounted) return;
      final hasFocus = FocusScope.of(context).hasFocus;
      final userTyping = hasFocus && _controller.text.isNotEmpty;
      if (userTyping) return;
      _controller.text = code;
      _autoSubmitted = false;
      _controller.selection = const TextSelection.collapsed(offset: 6);
      _handleTextChanged(code);
      return;

      // cerca esattamente 6 cifre isolate
      // ignore: unused_local_variable
    } catch (_) {
      // ignora errori clipboard
    }
  }

  void _showUuidLens() {
    if (_generatedUUID.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ID dispositivo',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _generatedUUID,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'monospace',
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleTextChanged(String value) {
    if (value.length > 6) {
      final truncated = value.substring(0, 6);
      _controller.text = truncated;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: truncated.length),
      );
    }

    _setStateIfMounted(() {});

    if (_controller.text.length == 6 && !_autoSubmitted) {
      _autoSubmitted = true;
      FocusScope.of(context).unfocus();
      if (_lAppAttiva) {
        _convertiInBase32();
      } else {
        // Avvisa l'utente che l'app non è attiva
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('App non attiva: impossibile generare il codice.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }

    if (_controller.text.length < 6) {
      _autoSubmitted = false;
      _converted = '';
    }
  }

  void _appendDigit(String digit) {
    if (_controller.text.length >= 6) {
      final newText = digit; // reset e riparti dal nuovo numero
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
      _handleTextChanged(newText);
      return;
    }
    final newText = _controller.text + digit;
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    _handleTextChanged(newText);
  }

  void _deleteLast() {
    if (_controller.text.isEmpty) return;
    final newText = _controller.text.substring(0, _controller.text.length - 1);
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    _handleTextChanged(newText);
  }

  void _clearAll() {
    _controller.clear();
    _controller.selection = const TextSelection.collapsed(offset: 0);
    _handleTextChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Platform.isWindows
          ? null
          : AppBar(title: const Text('Farma authenticator')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Codice generato in alto
                Text(
                  _converted,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                //const Text('Inserisci codice:'),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.normal),
                  keyboardType: Platform.isWindows
                      ? TextInputType.none
                      : TextInputType.number,
                  readOnly: Platform.isWindows ? false : true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'es: 123456',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onTap: () {
                    if (Platform.isWindows) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                    }
                  },
                  onChanged: _handleTextChanged,
                ),
                if (Platform.isWindows) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Il codice viene digitato nel programma in uso',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (!Platform.isWindows) ...[
                  const SizedBox(height: 12),
                  NumericKeypad(
                    onDigit: _appendDigit,
                    onBackspace: _deleteLast,
                    onClear: _clearAll,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "versione: $_version scadenza: $_datascadenza",
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              GestureDetector(
                onTap: _showUuidLens,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: _lAppAttiva ? 'App attiva' : 'App non attiva',
                      child: StatusLed(on: _lAppAttiva, size: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _generatedUUID,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
