import 'dart:typed_data';

Future<String?> saveDeviceRecording({
  required String fileName,
  required Uint8List bytes,
}) async => null;

Future<List<String>> listSavedDeviceRecordings() async => const [];

Future<bool> isDeviceRecordingSaved(String fileName) async => false;

Future<bool> openDeviceRecordingsDirectory() async => false;
