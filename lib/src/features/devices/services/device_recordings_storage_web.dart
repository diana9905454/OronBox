import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> saveDeviceRecording({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (bytes.isEmpty) return null;
  final safeName = fileName.isEmpty ? 'recording.opus' : fileName;
  final mimeType = safeName.endsWith('.pcm')
      ? 'audio/x-raw'
      : safeName.endsWith('.wav')
      ? 'audio/wav'
      : 'audio/opus';
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = safeName
    ..style.display = 'none';
  try {
    web.document.body!.appendChild(anchor);
    anchor.click();
    return safeName;
  } finally {
    anchor.remove();
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  }
}

Future<List<String>> listSavedDeviceRecordings() async => const [];

Future<bool> isDeviceRecordingSaved(String fileName) async => false;

Future<bool> openDeviceRecordingsDirectory() async => false;
