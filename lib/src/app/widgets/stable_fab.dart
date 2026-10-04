import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';

const stableFabAnimationDuration = Duration(milliseconds: 180);

class StableFabSwitcher extends StatelessWidget {
  const StableFabSwitcher({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: stableFabAnimationDuration,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: child,
  );
}

class StableExtendedFab extends StatelessWidget {
  const StableExtendedFab({
    required this.heroTag,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.animationKey,
    this.secondary = false,
    super.key,
  });

  final Object heroTag;
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final Object? animationKey;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: secondary
          ? Theme.of(context).useMaterial3
                ? colors.secondaryContainer
                : context.appSelectionContainer
          : null,
      foregroundColor: secondary
          ? Theme.of(context).useMaterial3
                ? colors.onSecondaryContainer
                : context.appSelectionForeground
          : null,
      icon: _StableFabContent(
        contentKey: ValueKey((animationKey, 'icon')),
        child: icon,
      ),
      label: _StableFabContent(
        contentKey: ValueKey((animationKey, 'label')),
        child: label,
      ),
    );
  }
}

class _StableFabContent extends StatelessWidget {
  const _StableFabContent({required this.contentKey, required this.child});

  final Key contentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: stableFabAnimationDuration,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: KeyedSubtree(key: contentKey, child: child),
  );
}
