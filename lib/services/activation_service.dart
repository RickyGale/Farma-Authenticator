import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

const _expirationKey = 'DataScadenza';
const _minVersionKey = 'VersioneMinima';

class ActivationResult {
  const ActivationResult({
    required this.active,
    required this.expiration,
    this.requiredVersion,
    this.errorMessage,
  });

  final bool active;
  final String expiration;

  /// Versione minima chiesta dal server, valorizzata solo se quella
  /// installata è più vecchia: in quel caso l'app va aggiornata.
  final String? requiredVersion;
  final String? errorMessage;

  bool get updateRequired => requiredVersion != null;
}

class ActivationService {
  Future<ActivationResult> register({
    required String deviceId,
    required String platform,
  }) async {
    // Letta qui e non passata dalla pagina: lì potrebbe non essere ancora pronta
    final version = (await PackageInfo.fromPlatform()).version;
    final result = await _registerOnServer(
      deviceId: deviceId,
      platform: platform,
      version: version,
    );
    if (!Platform.isWindows) return result;
    // Su Windows attivano i file (come MM5): il server registra soltanto il dispositivo
    return ActivationResult(
      active: await _windowsRequiredFilesPresent(),
      expiration: result.expiration,
      requiredVersion: result.requiredVersion,
      errorMessage: result.errorMessage,
    );
  }

  Future<ActivationResult> _registerOnServer({
    required String deviceId,
    required String platform,
    required String version,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(registrationUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'device_id': deviceId,
              'platform': platform,
              'version': version,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        // Formato: "dd-MM-yy" oppure "dd-MM-yy;versione_minima"
        final parts = response.body.trim().split(';');
        final expiration = parts[0].trim();
        final minVersion = parts.length > 1 ? parts[1].trim() : '';
        final active = _isNotExpired(expiration);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_expirationKey, expiration);
        // Salvata per non sbloccare l'app vecchia semplicemente andando offline
        if (minVersion.isEmpty) {
          await prefs.remove(_minVersionKey);
        } else {
          await prefs.setString(_minVersionKey, minVersion);
        }
        debugPrint('Registrazione ok: v$version, minima "$minVersion"');
        return ActivationResult(
          active: active,
          expiration: expiration,
          requiredVersion: _requiredVersion(version, minVersion),
        );
      }
      debugPrint('Errore server: ${response.statusCode} - ${response.body}');
      return await _savedActivation(
        'Errore server: ${response.statusCode}.',
        version,
      );
    } catch (error) {
      debugPrint('Errore rete: $error');
      return _savedActivation('Errore rete.', version);
    }
  }

  /// [minVersion] se [version] è più vecchia, altrimenti null.
  String? _requiredVersion(String version, String minVersion) {
    if (minVersion.isEmpty) return null;
    return _compareVersions(version, minVersion) < 0 ? minVersion : null;
  }

  /// Confronta "1.13.07" con "1.14.0" parte per parte, come numeri;
  /// l'eventuale "+build" viene ignorato.
  int _compareVersions(String a, String b) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Attiva solo se la scadenza è successiva a oggi: il giorno di scadenza
  /// conta già come non attivo. Lancia [FormatException] se la data non è valida.
  bool _isNotExpired(String expiration) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateFormat('dd-MM-yy').parse(expiration).isAfter(today);
  }

  Future<ActivationResult> _savedActivation(
    String errorPrefix,
    String version,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_expirationKey);
    final minVersion = prefs.getString(_minVersionKey) ?? '';
    var active = false;
    if (stored != null && stored.isNotEmpty) {
      try {
        active = _isNotExpired(stored);
      } catch (_) {}
    }
    final expiration = stored ?? '';
    final savedLabel = expiration.isEmpty ? 'nessuna' : expiration;
    return ActivationResult(
      active: active,
      expiration: expiration,
      requiredVersion: _requiredVersion(version, minVersion),
      errorMessage: '$errorPrefix Uso data salvata: $savedLabel',
    );
  }

  Future<bool> _windowsRequiredFilesPresent() async {
    if (!Platform.isWindows) return true;
    try {
      final path1 =
          Platform.environment['FARMA_FILE1_PATH'] ?? winRequiredFile1;
      final path2 =
          Platform.environment['FARMA_FILE2_PATH'] ?? winRequiredFile2;
      final exists1 = await File(
        path1,
      ).exists().timeout(const Duration(seconds: 2), onTimeout: () => false);
      final exists2 = await File(
        path2,
      ).exists().timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (!exists1 || !exists2) {
        debugPrint(
          'File richiesti non trovati su Windows: e1=$exists1 path1=$path1, e2=$exists2 path2=$path2',
        );
      }
      return exists1 && exists2;
    } catch (_) {
      return false;
    }
  }
}
