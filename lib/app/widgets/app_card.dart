import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(AppSpacing.lg),
      this.onTap,
      this.margin});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppElevation.level1,
        border:
            Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: card);
  }
}
