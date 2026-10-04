import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';

class DraftAsset {
  DraftAsset({
    required this.key,
    required this.name,
    this.bytes,
    this.sha256 = '',
    this.sizeBytes = 0,
    this.width = 0,
    this.height = 0,
    this.packageId = '',
    this.version = '',
    this.type = '',
  });

  final String key;
  String name;
  Uint8List? bytes;
  final String sha256;
  final int sizeBytes;
  int width;
  int height;
  final String packageId;
  final String version;
  final String type;

  int? get size => bytes?.length ?? (sizeBytes > 0 ? sizeBytes : null);
}

class DraftLink {
  DraftLink({String title = '', String url = ''})
    : title = TextEditingController(text: title),
      url = TextEditingController(text: url);

  final TextEditingController title;
  final TextEditingController url;

  void dispose() {
    title.dispose();
    url.dispose();
  }
}
