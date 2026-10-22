import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Riconoscimento testo su iOS tramite Apple Vision (ios/Runner/VisionTextRecognizer.swift).
/// ML Kit resta solo su Android perché su iOS non supporta i simulatori arm64.
class VisionTextRecognizer {
  static const MethodChannel _channel = MethodChannel('farma_auth/vision_text');

  /// Restituisce il testo letto, una riga per osservazione.
  Future<String> processImage(InputImage inputImage) async {
    final metadata = inputImage.metadata!;
    final text = await _channel.invokeMethod<String>('processImage', {
      'bytes': inputImage.bytes!,
      'width': metadata.size.width.toInt(),
      'height': metadata.size.height.toInt(),
      'bytesPerRow': metadata.bytesPerRow,
      'rotation': metadata.rotation.rawValue,
    });
    return text ?? '';
  }
}
