import 'package:material_ui/material_ui.dart';

const appSnackBarDuration = Duration(seconds: 2);

/// Applies the app-wide SnackBar duration without requiring every call site to
/// repeat the same value.
class OronBoxScaffoldMessenger extends ScaffoldMessenger {
  const OronBoxScaffoldMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _OronBoxScaffoldMessengerState();
}

class _OronBoxScaffoldMessengerState extends ScaffoldMessengerState {
  String? _lastMessage;
  DateTime? _lastShownTime;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentController;

  String? _extractText(Widget content) {
    if (content is Text) return content.data ?? content.textSpan?.toPlainText();
    return null;
  }

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final text = _extractText(snackBar.content);
    final now = DateTime.now();

    if (text != null &&
        _lastMessage == text &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!) < const Duration(seconds: 2) &&
        _currentController != null) {
      return _currentController!;
    }

    _lastMessage = text;
    _lastShownTime = now;

    // Clear previous queued SnackBars so errors across multiple concurrent
    // requests don't pile up into a long chain of successive notifications.
    clearSnackBars();

    final duration = snackBar.duration > appSnackBarDuration
        ? appSnackBarDuration
        : snackBar.duration;
    final controller = super.showSnackBar(
      SnackBar(
        key: snackBar.key,
        content: snackBar.content,
        backgroundColor: snackBar.backgroundColor,
        elevation: snackBar.elevation,
        margin: snackBar.margin,
        padding: snackBar.padding,
        width: snackBar.width,
        shape: snackBar.shape,
        hitTestBehavior: snackBar.hitTestBehavior,
        behavior: snackBar.behavior,
        action: snackBar.action,
        actionOverflowThreshold: snackBar.actionOverflowThreshold,
        showCloseIcon: snackBar.showCloseIcon,
        closeIconColor: snackBar.closeIconColor,
        duration: duration,
        persist: snackBar.persist,
        animation: snackBar.animation,
        onVisible: snackBar.onVisible,
        dismissDirection: snackBar.dismissDirection,
        clipBehavior: snackBar.clipBehavior,
      ),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
    _currentController = controller;
    controller.closed.whenComplete(() {
      if (identical(_currentController, controller)) {
        _currentController = null;
      }
    });
    return controller;
  }
}
