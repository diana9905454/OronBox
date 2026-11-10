import 'dart:ffi';
import 'dart:io';

String releasePlatform() => Platform.operatingSystem;
String releaseArchitecture() {
  if (Platform.isMacOS) return 'universal';
  final abi = Abi.current().toString();
  if (abi.contains('arm64')) return 'arm64';
  if (abi.contains('x64')) return 'amd64';
  return '';
}
