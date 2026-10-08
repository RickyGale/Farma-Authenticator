class OcrCodeExtractor {
  const OcrCodeExtractor._();

  static String? extract(String text) {
    final candidates = RegExp(
      r'(?<!\d)\d{6}(?!\d)',
    ).allMatches(text).map((match) => match.group(0)!).toSet();
    return candidates.length == 1 ? candidates.single : null;
  }
}
