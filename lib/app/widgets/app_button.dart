import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.isPrimary = true,
      this.isLoading = false,
      this.backgroundColor,
      this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    ButtonStyle? style;

    if (backgroundColor != null || foregroundColor != null) {
      // Use custom colors if provided
      style = ElevatedButton.styleFrom(
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.primary,
        foregroundColor:
            foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
      );
    } else {
      // Use existing logic for primary/secondary
      style = isPrimary
          ? Theme.of(context).elevatedButtonTheme.style
          : ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md)),
            );
    }

    // Determine the correct color for the loading indicator
    Color loadingColor;
    if (foregroundColor != null) {
      loadingColor = foregroundColor!;
    } else if (backgroundColor != null) {
      loadingColor = Theme.of(context).colorScheme.onPrimary;
    } else if (isPrimary) {
      loadingColor = Theme.of(context).colorScheme.onPrimary;
    } else {
      loadingColor = Theme.of(context).colorScheme.onSecondary;
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
              ),
            )
          : Text(label),
    );
  }
}
