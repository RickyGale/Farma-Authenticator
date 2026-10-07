import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ActivationResult {
  const ActivationResult({
    required this.active,
    required this.expiration,
    this.errorMessage,
  });

  final bool active;
  final String expiration;
  final String? errorMessage;
}

class ActivationService {
  Future<ActivationResult> register({
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
        DateFormat('dd-MM-yy').parse(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('DataScadenza', response.body);
        debugPrint('Registrazione ok');
        return ActivationResult(active: true, expiration: response.body);
      }
      debugPrint('Errore server: ${response.statusCode} - ${response.body}');
      return await _savedActivation(
        'Errore server: ${response.statusCode}.',
        includeSameDay: true,
      );
    } catch (error) {
      debugPrint('Errore rete: $error');
      return _savedActivation('Errore rete.', includeSameDay: false);
    }
  }

  Future<ActivationResult> _savedActivation(
    String errorPrefix, {
    required bool includeSameDay,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('DataScadenza');
    final filesPresent = await _windowsRequiredFilesPresent();
    var active = false;
    if (stored != null && stored.isNotEmpty) {
      try {
        final expiration = DateFormat('dd-MM-yy').parse(stored);
        active =
            expiration.isAfter(DateTime.now()) ||
            (includeSameDay && expiration.isAtSameMomentAs(DateTime.now()));
      } catch (_) {}
    }
    final expiration = stored ?? '';
    final savedLabel = expiration.isEmpty ? 'nessuna' : expiration;
    return ActivationResult(
      active: active && (!Platform.isWindows || filesPresent),
      expiration: expiration,
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
