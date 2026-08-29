import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';

/// 鸿蒙端 file_picker 桥接实现。
///
/// OronBox 用 file_picker 选文件/选图/保存文件，鸿蒙端无原生实现。
/// 本类继承 [FilePickerPlatform]，在鸿蒙端通过自定义 channel `oronbox/file_picker`
/// 调鸿蒙的 [PhotoViewPicker]（选图）或 [DocumentViewPicker]（选文件/保存文件）。
class OhosFilePickerPlatform extends FilePickerPlatform {
  static const MethodChannel _method = MethodChannel('oronbox/file_picker');

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final paths = await _pick(
      isImage: _wantsImageOnly(type),
      maxSelectNumber: 1,
      suffixFilter: allowedExtensions,
    );
    if (paths.isEmpty) return null;
    return _OhosPlatformFile.fromPath(paths.first);
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final paths = await _pick(
      isImage: _wantsImageOnly(type),
      maxSelectNumber: allowedExtensions == null ? 0 : 0, // 0 = 不限数量
      suffixFilter: allowedExtensions,
    );
    return paths.map(_OhosPlatformFile.fromPath).toList(growable: false);
  }

  @override
  Future<List<String>> pickFileAndDirectoryPaths({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    return _pick(
      isImage: false,
      maxSelectNumber: 0,
      suffixFilter: allowedExtensions,
    );
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    // 鸿蒙 DocumentViewPicker 没有「选目录」语义，平台不支持，返回 null 让 UI 提示。
    return null;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    try {
      final savedUri = await _method.invokeMethod<String>('saveFile', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeType,
      });
      return savedUri == null ? null : Uri.parse(savedUri);
    } on PlatformException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  Future<List<String>> _pick({
    required bool isImage,
    required int maxSelectNumber,
    List<String>? suffixFilter,
  }) async {
    try {
      final result = await _method.invokeMethod<List<dynamic>>('pick', {
        'isImage': isImage,
        'maxSelectNumber': maxSelectNumber,
        'suffixFilter': suffixFilter,
      });
      if (result == null) return const [];
      return result.cast<String>();
    } on PlatformException {
      return const [];
    }
  }

  /// 判断是否「只要图片」。FileType.image / media / video / any。
  bool _wantsImageOnly(FileType type) {
    return type == FileType.image || type == FileType.media;
  }
}

/// PlatformFile 简易实现：通过文件路径构造 XFile、读取 size/bytes。
base class _OhosPlatformFile extends PlatformFile {
  _OhosPlatformFile._(this._path);

  factory _OhosPlatformFile.fromPath(String path) {
    return _OhosPlatformFile._(path);
  }

  final String _path;

  @override
  String get name {
    final path = _path;
    final i = path.lastIndexOf('/');
    if (i < 0) return path;
    final j = path.lastIndexOf('\\');
    if (j > i) return path.substring(j + 1);
    return path.substring(i + 1);
  }

  @override
  Uri get uri => Uri.file(_path);

  @override
  XFile get xFile => XFile(_path, name: name);

  @override
  Future<int> length() async => 0; // 长度由调用方按需懒加载

  @override
  Future<Uint8List> readAsBytes() async {
    // 通过 channel 读文件字节（鸿蒙端用 fileRead 读）。
    try {
      final data = await OhosFilePickerPlatform._method.invokeMethod<Uint8List>(
        'readFile',
        {'path': _path},
      );
      return data ?? Uint8List(0);
    } catch (_) {
      return Uint8List(0);
    }
  }

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}
