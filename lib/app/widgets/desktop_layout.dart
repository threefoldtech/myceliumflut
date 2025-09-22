import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'desktop_sidebar.dart';

class DesktopLayout extends StatelessWidget {
  final Widget title;
  final Widget child;
  final int currentIndex;

  const DesktopLayout({
    super.key,
    required this.title,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          DesktopSidebar(currentIndex: currentIndex),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Header bar
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    child: Row(
                      children: [
                        Expanded(child: title),
                      ],
                    ),
                  ),
                ),

                // Main content with proper padding
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.background,
                    width: double.infinity,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
