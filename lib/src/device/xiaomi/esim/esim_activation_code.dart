/// A standard GSMA eSIM Activation Code extracted from a QR payload.
class XiaomiEsimActivationCode {
  const XiaomiEsimActivationCode({
    required this.value,
    required this.elements,
    this.retryDownload = false,
  });

  final String value;
  final List<String> elements;
  final bool retryDownload;

  /// Parses the QR text accepted by the Xiaomi LPA flow.
  ///
  /// Mi Fitness removes the optional case-insensitive `LPA:` prefix and
  /// expects a versioned, `$`-separated Activation Code beginning with `1`.
  static XiaomiEsimActivationCode? parse(String raw) {
    var value = raw.trim();
    if (value.length >= 4 && value.substring(0, 4).toLowerCase() == 'lpa:') {
      value = value.substring(4).trim();
    }
    if (value.isEmpty) return null;

    final elements = value.split(r'$');
    if (elements.length < 3 ||
        elements.first != '1' ||
        elements[1].trim().isEmpty ||
        elements[2].trim().isEmpty) {
      return null;
    }
    return XiaomiEsimActivationCode(
      value: value,
      elements: List.unmodifiable(elements),
      retryDownload: elements.length > 4 && elements[4] == '1',
    );
  }
}
