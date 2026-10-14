class OcrCodeExtractor {
  const OcrCodeExtractor._();

  static String? extract(String text) {
    final candidates = RegExp(r'(?<!\d)(?:\d\s*){6}(?!\d)')
        .allMatches(text)
        .map((match) {
          return match.group(0)!.replaceAll(RegExp(r'\s'), '');
        })
        .toSet();
    return candidates.length == 1 ? candidates.single : null;
  }
}
