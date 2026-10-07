class CodeGenerator {
  static const _alphabet = '0123456789BCDFGHJKLMNPQRSTUVWXYZ';

  String generate(String code) {
    final base32 = _toBase32(int.parse('123$code'));
    return '${base32[2]}${base32[5]}${base32[1]}${base32[3]}';
  }

  String _toBase32(int number) {
    if (number == 0) return '0';
    var result = '';
    while (number > 0) {
      result = _alphabet[number % 32] + result;
      number ~/= 32;
    }
    return result;
  }
}
