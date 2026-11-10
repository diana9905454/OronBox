import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, compute, debugPrint;
import 'package:flutter/services.dart'
    show MethodChannel, PlatformException, MissingPluginException;
import 'package:image/image.dart' as image;
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_zxing/flutter_zxing.dart' as zxing;
import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';

/// 鸿蒙侧的扫一扫通道（ohos/entry/src/main/ets/plugins/QrScanBridge.ets）。
const _systemQrScanChannel = MethodChannel('oronbox/qr_scan');

/// 鸿蒙没有 camera 插件，flutter_zxing 的取景页在那边只能"从图片识别"，
/// 因此改调系统 Scan Kit 的扫码界面：相机由系统托管（无需申请权限），
/// 自带相册入口，取消时原生侧回 null。
Future<String?> _scanWithSystemPage({String? title}) async {
  try {
    final value = await _systemQrScanChannel.invokeMethod<String>('scan', {
      'title': title,
    });
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  } on PlatformException catch (error) {
    debugPrint('System QR scan failed: ${error.code} ${error.message}');
    return null;
  } on MissingPluginException catch (error) {
    debugPrint('System QR scan unavailable: $error');
    return null;
  }
}

Future<String?> showQrScannerPage(BuildContext context, {String? title}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.ohos) {
    return _scanWithSystemPage(title: title);
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => QrScannerPage(title: title)),
  );
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({this.title, super.key});

  final String? title;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _completed = false;
  bool _pickingImage = false;
  bool _cameraFailed = false;
  int _cameraGeneration = 0;

  bool get _supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _finish(String? text) {
    if (_completed || !mounted || text == null || text.trim().isEmpty) return;
    _completed = true;
    Navigator.of(context).pop(text.trim());
  }

  void _cameraError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_completed && !_pickingImage) {
        setState(() => _cameraFailed = true);
      }
    });
  }

  Future<void> _pickImage() async {
    if (_pickingImage || _completed) return;
    setState(() => _pickingImage = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      // Unmount the camera before opening the picker or a result dialog.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final selected = await pickFileData(type: FileType.image);
      if (!mounted || selected == null) return;
      final result = await compute(_decodeQrImage, selected);
      if (!mounted || _completed) return;
      if (result.failed) {
        _showMessage(l10n.qrScanImageFailed);
        return;
      }
      final values = result.values;
      if (values.isEmpty) {
        _showMessage(l10n.qrScanNoCode);
      } else if (values.length == 1) {
        _finish(values.single);
      } else {
        final selected = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.qrScanChooseCode),
            content: SizedBox(
              width: 420,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: values.length,
                itemBuilder: (_, index) => ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text(l10n.qrScanCodeLabel(index + 1)),
                  onTap: () => Navigator.of(dialogContext).pop(values[index]),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
        _finish(selected);
      }
    } catch (_) {
      if (mounted && !_completed) _showMessage(l10n.qrScanImageFailed);
    } finally {
      if (mounted && !_completed) setState(() => _pickingImage = false);
    }
  }

  void _showMessage(String text) {
    appScaffoldMessengerOf(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(widget.title ?? l10n.scanQrCode),
      ),
      body: PageContainer(
        maxWidth: 560,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight;
                  return Center(
                    child: SizedBox.square(
                      dimension: size,
                      child: Card.outlined(
                        color: colors.surfaceContainerLow,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            cardRadiusFor(context),
                          ),
                          side: BorderSide(color: colors.primary, width: 2),
                        ),
                        child: _pickingImage
                            ? const Center(child: CircularProgressIndicator())
                            : !_supportsCamera || _cameraFailed
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_scanner,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        kIsWeb
                                            ? l10n.qrScanUnsupported
                                            : l10n.qrScanCameraUnavailable,
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_supportsCamera)
                                        TextButton(
                                          onPressed: () => setState(() {
                                            _cameraFailed = false;
                                            _cameraGeneration++;
                                          }),
                                          child: Text(l10n.retry),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : flutter.Theme(
                                data: flutter.ThemeData(
                                  colorScheme: flutter.ColorScheme.fromSeed(
                                    seedColor: colors.primary,
                                  ),
                                ),
                                child: zxing.ReaderWidget(
                                  key: ValueKey(_cameraGeneration),
                                  codeFormat: zxing.Format.qrCode,
                                  showGallery: false,
                                  showToggleCamera: false,
                                  showFlashlight: false,
                                  showScannerOverlay: false,
                                  cropPercent: 0,
                                  scanDelay: const Duration(milliseconds: 200),
                                  tryRotate: true,
                                  tryInverted: true,
                                  loading: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  onScan: (code) {
                                    if (!_pickingImage && code.isValid) {
                                      _finish(code.text);
                                    }
                                  },
                                  onControllerCreated: (_, error) {
                                    if (error != null) _cameraError();
                                  },
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FilledButton.tonal(
                  onPressed: _pickingImage || kIsWeb ? null : _pickImage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined),
                      const SizedBox(width: 8),
                      Text(l10n.qrScanFromImage),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<({List<String> values, bool failed})> _decodeQrImage(
  PickedFileData selected,
) async {
  final file = selected.xFile;
  if (file == null || await file.length() > 20 * 1024 * 1024) {
    return (values: <String>[], failed: true);
  }
  final bytes = await file.readAsBytes();
  final decoder = image.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 32000000) {
    return (values: <String>[], failed: true);
  }
  final result = await zxing.zx.readBarcodesImagePath(
    file,
    zxing.DecodeParams(
      format: zxing.Format.qrCode,
      tryHarder: true,
      tryRotate: true,
      tryInverted: true,
      tryDownscale: true,
      maxSize: 2048,
      maxNumberOfSymbols: 16,
      isMultiScan: true,
    ),
  );
  return (
    values: result.codes
        .where((code) => code.isValid)
        .map((code) => code.text?.trim())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .toSet()
        .toList(),
    failed: result.error != null && result.codes.isEmpty,
  );
}
