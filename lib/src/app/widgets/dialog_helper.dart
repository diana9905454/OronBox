import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oronbox/src/core/utils/layout.dart';

class OronBoxDialog {
  OronBoxDialog._internal();

  static final OronBoxDialogObserver observer = OronBoxDialogObserver();

  static Future<T?> show<T>({
    BuildContext? context,
    bool? clickMaskDismiss,
    VoidCallback? onDismiss,
    required WidgetBuilder builder,
  }) async {
    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final result = await showDialog<T>(
          context: ctx,
          barrierDismissible: clickMaskDismiss ?? true,
          builder: builder,
          routeSettings: const RouteSettings(name: 'OronBoxDialog'),
        );
        onDismiss?.call();
        return result;
      } catch (e) {
        debugPrint('OronBoxDialog: failed to show dialog: $e');
        return null;
      }
    }
    debugPrint('OronBoxDialog: no context available');
    return null;
  }

  static void showToast({
    required String message,
    BuildContext? context,
    bool showActionButton = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration duration = const Duration(seconds: 2),
  }) {
    final ctx = context ?? observer.scaffoldContext;
    if (ctx != null && ctx.mounted) {
      try {
        ScaffoldMessenger.of(ctx)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              width: useWideLayout(MediaQuery.sizeOf(ctx).width) ? 600 : null,
              duration: duration,
              action: showActionButton
                  ? SnackBarAction(
                      label: actionLabel ?? 'Dismiss',
                      onPressed: () {
                        onActionPressed?.call();
                        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                      },
                    )
                  : null,
            ),
          );
      } catch (e) {
        debugPrint('OronBoxDialog: failed to show toast: $e');
      }
    }
  }

  static Future<void> showLoading({
    BuildContext? context,
    String? msg,
    bool barrierDismissible = false,
  }) async {
    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      await showDialog(
        context: ctx,
        barrierDismissible: barrierDismissible,
        builder: (context) => Center(
          child: Card(
            elevation: 8,
            shape: Theme.of(context).cardTheme.shape,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    msg ?? 'Loading...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        routeSettings: const RouteSettings(name: 'OronBoxDialog'),
      );
    }
  }

  static Future<T?> showBottomSheet<T>({
    BuildContext? context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    final ctx = context ?? observer.rootContext;
    if (ctx != null && ctx.mounted) {
      return showModalBottomSheet<T>(
        context: ctx,
        builder: builder,
        isScrollControlled: isScrollControlled,
        useRootNavigator: useRootNavigator,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        routeSettings: const RouteSettings(name: 'OronBoxBottomSheet'),
      );
    }
    return null;
  }

  static void dismiss<T>({T? popWith}) {
    if (observer.hasDialog && observer.dialogContext != null) {
      Navigator.of(observer.dialogContext!).pop(popWith);
    }
  }
}

class OronBoxDialogObserver extends NavigatorObserver {
  final List<Route<dynamic>> _dialogRoutes = [];
  BuildContext? _currentContext;
  BuildContext? _scaffoldContext;
  BuildContext? _rootContext;

  BuildContext? get currentContext => _currentContext;
  BuildContext? get scaffoldContext => _scaffoldContext ?? _currentContext;
  BuildContext? get rootContext =>
      _rootContext ?? _scaffoldContext ?? _currentContext;
  bool get hasDialog => _dialogRoutes.isNotEmpty;
  BuildContext? get dialogContext =>
      _dialogRoutes.isNotEmpty ? _dialogRoutes.last.navigator?.context : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isDialogRoute(route)) _dialogRoutes.add(route);
    if (route.navigator?.context != null) {
      _updateContexts(route.navigator!.context, route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_isDialogRoute(route)) _dialogRoutes.remove(route);
    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context, previousRoute);
    }
  }

  void _updateContexts(BuildContext context, Route<dynamic> route) {
    _currentContext = context;
    if (Scaffold.maybeOf(context) != null) {
      _scaffoldContext = context;
      _rootContext = context;
    }
  }

  bool _isDialogRoute(Route<dynamic> route) {
    return route.settings.name == 'OronBoxDialog' ||
        route.settings.name == 'OronBoxBottomSheet';
  }
}
