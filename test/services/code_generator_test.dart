import 'package:farma_auth/services/code_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeGenerator', () {
    final generator = CodeGenerator();

    test('mantiene la conversione e il riordino esistenti', () {
      expect(generator.generate('000000'), '90PP');
      expect(generator.generate('123456'), 'F0PF');
      expect(generator.generate('999999'), '8ZQ5');
    });

    test('rifiuta input non numerici', () {
      expect(() => generator.generate('ABCDEF'), throwsFormatException);
    });
  });
}
