import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> saveXiaomiScreenshot(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  final fileName = 'IMG_${DateTime.now().microsecondsSinceEpoch}.png';
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  try {
    web.document.body!.appendChild(anchor);
    anchor.click();
    return fileName;
  } finally {
    anchor.remove();
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  }
}
