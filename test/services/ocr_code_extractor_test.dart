import 'package:farma_auth/services/ocr_code_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrCodeExtractor', () {
    test('estrae un codice isolato di sei cifre', () {
      expect(OcrCodeExtractor.extract('Codice: #123456#'), '123456');
    });

    test('ignora sequenze con una lunghezza diversa', () {
      expect(
        OcrCodeExtractor.extract('ID 12345 e riferimento 1234567'),
        isNull,
      );
    });

    test('rifiuta una lettura ambigua', () {
      expect(OcrCodeExtractor.extract('123456 oppure 654321'), isNull);
    });

    test('accetta ripetizioni dello stesso codice', () {
      expect(OcrCodeExtractor.extract('123456\n123456'), '123456');
    });
  });
}
