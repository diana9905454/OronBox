import 'dart:async';

import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';

import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/router/app_router.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/window/desktop_window.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/plugins/domain/plugin_package.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_install_confirmation.dart';
import 'package:oronbox/src/features/resources/widgets/resource_install_confirmation.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

/// File extensions the app claims as "open with" targets. Content is still
/// detected from the package itself before installation.
const _handledExtensions = <String>{
  'rpk',
  'bin',
  'face',
  'zpk',
  'mwz',
  'obp',
  'abp',
};

enum _PluginFileResult { notPlugin, handled }

/// Receives files opened with OronBox from the OS file manager. Every native
/// platform pushes the resolved local path through the `oronbox/file_open`
/// method channel (cold and warm start alike), so this widget only needs one
/// listener; it then routes the file through the same confirmation/enqueue
/// flow used by drag-and-drop.
class FileOpenHandler extends ConsumerStatefulWidget {
  const FileOpenHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FileOpenHandler> createState() => _FileOpenHandlerState();
}

class _FileOpenHandlerState extends ConsumerState<FileOpenHandler> {
  static const _channel = MethodChannel('oronbox/file_open');
  final Set<String> _handledPaths = {};
  StreamSubscription<List<String>>? _launchArgumentsSubscription;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleCall);
    _launchArgumentsSubscription = primaryLaunchArguments.listen((arguments) {
      // The stream can replay queued arguments while this widget is still
      // being mounted, before the root navigator has a context. Wait for the
      // next frame so the file is not silently dropped.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final argument in arguments) {
          unawaited(_openFile(argument));
        }
      });
    });
    // Cold start: the native side may have received an "open with" intent
    // before Flutter finished initializing, so it cannot push through the
    // channel yet; pull the initial file once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await _channel.invokeMethod<String?>('getInitialFile');
      if (initial != null && mounted) {
        await _openFile(initial);
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _launchArgumentsSubscription?.cancel();
    super.dispose();
  }

  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method == 'openFile') {
      final path = call.arguments as String?;
      if (path != null && mounted) {
        await _openFile(path);
      }
    }
    return null;
  }

  Future<void> _openFile(String path) async {
    if (!_handledExtensions.contains(_extensionOf(path))) return;
    final file = XFile(path);
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;
    if (!_handledPaths.add(path)) return;
    await _installFiles([file], navigatorContext);
  }

  Future<_PluginFileResult> _installPlugin(
    XFile file,
    BuildContext context,
  ) async {
    final extension = _extensionOf(file.name);
    if (!const {'obp', 'abp', 'zip'}.contains(extension)) {
      return _PluginFileResult.notPlugin;
    }
    late final Uint8List bytes;
    late final PluginPackage package;
    try {
      bytes = await file.readAsBytes();
      package = const PluginPackageReader().read(bytes);
    } catch (_) {
      if (extension == 'zip') return _PluginFileResult.notPlugin;
      rethrow;
    }

    final host = ref.read(applicationHostProvider);
    final listResult = await host.execute(
      const OronBoxCommand(
        method: 'plugin.list',
        params: {'includeIcons': false},
      ),
    );
    if (!listResult.ok) {
      throw listResult.error!;
    }
    final manifest = package.manifest;
    final updating = (listResult.value as List? ?? const [])
        .whereType<Map>()
        .any((plugin) => plugin['id']?.toString() == manifest.id);
    if (!context.mounted ||
        !await confirmPluginInstall(
          context: context,
          name: manifest.name,
          permissions: manifest.permissions,
          updating: updating,
          legacy: manifest.runtime == PluginRuntimeType.legacy,
        )) {
      return _PluginFileResult.handled;
    }
    final result = await host.execute(
      OronBoxCommand(
        method: 'plugin.install',
        params: {'bytes': base64Encode(bytes), 'includeIcon': false},
      ),
    );
    if (!result.ok) {
      throw result.error!;
    }
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      appScaffoldMessengerOf(context).showSnackBar(
        SnackBar(content: Text('${manifest.name}: ${l10n.pluginInstalled}')),
      );
    }
    return _PluginFileResult.handled;
  }

  Future<void> _installFiles(
    Iterable<XFile> files,
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    var enqueued = 0;
    for (final file in files) {
      if (!context.mounted) return;
      try {
        if (await _installPlugin(file, context) == _PluginFileResult.handled) {
          continue;
        }
        if (context.mounted &&
            await confirmAndEnqueueResourceFile(
              context: context,
              ref: ref,
              file: file,
            )) {
          enqueued++;
        }
      } catch (error) {
        if (!context.mounted) return;
        if (_isPluginPackageError(error)) {
          await _showPluginPackageCorruptedDialog(context);
          continue;
        }
        appScaffoldMessengerOf(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l10n, error))),
        );
      }
    }
    if (!context.mounted || enqueued == 0) return;
    appScaffoldMessengerOf(context)
        .showSnackBar(SnackBar(content: Text(l10n.queueAddedFiles(enqueued))));
  }

  Future<void> _showPluginPackageCorruptedDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pluginErrorTitle),
        content: Text(l10n.pluginPackageCorruptedMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  bool _isPluginPackageError(Object error) {
    final message = switch (error) {
      CommandError(:final message) => message,
      FormatException(:final message) => message,
      _ => error.toString(),
    };
    return message.contains('ABP manifest.json is missing') ||
        message.contains('ABP package') ||
        message.contains('ABP entry is missing');
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragEntered: (_) => setState(() => _dragging = true),
    onDragExited: (_) => setState(() => _dragging = false),
    onDragDone: (detail) async {
      setState(() => _dragging = false);
      final files = detail.files
          .where((file) => file.path.isNotEmpty)
          .toList(growable: false);
      final navigatorContext = rootNavigatorKey.currentContext;
      if (files.isNotEmpty && navigatorContext != null) {
        await _installFiles(files, navigatorContext);
      }
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.upload_file,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.queueDragToInstall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
