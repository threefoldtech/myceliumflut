import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  const AppButton({super.key, required this.label, this.onPressed, this.isPrimary = true, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final style = isPrimary
        ? Theme.of(context).elevatedButtonTheme.style
        : ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          );
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }
}


