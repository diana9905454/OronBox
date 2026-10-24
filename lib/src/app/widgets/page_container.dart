import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = StyleConstants.pageMaxWidth,
    this.padding = const EdgeInsets.symmetric(
      horizontal: StyleConstants.pagePadding,
      vertical: StyleConstants.pagePadding,
    ),
    this.center = true,
    this.safeArea = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool center;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    // Secondary pages are pushed on the root navigator and reach the system
    // navigation area; inside the tab shell the bottom padding is already
    // consumed by the NavigationBar, so this is a no-op there.
    final content = Padding(padding: padding, child: child);
    final body = safeArea ? SafeArea(top: false, child: content) : content;
    if (!center) return body;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: body,
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StyleConstants.pagePadding),
    this.margin = const EdgeInsets.only(bottom: StyleConstants.sectionSpacing),
    this.borderRadius,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius =
        borderRadius ?? BorderRadius.circular(cardRadiusFor(context));
    return Card(
      elevation: 0,
      margin: margin,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.leading,
  });

  final String title;
  final Widget? action;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 计算可滚动列表或页面的底部安全边距，自适应全面屏系统手势横条与安全区
double bottomContentPadding(BuildContext context, {double extra = 16}) {
  final viewPaddingBottom = MediaQuery.paddingOf(context).bottom;
  return viewPaddingBottom + extra;
}

