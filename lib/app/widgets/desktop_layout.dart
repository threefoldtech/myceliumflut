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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Row(
          children: [
            // Sidebar
            DesktopSidebar(currentIndex: currentIndex),

            // Main content area
            Expanded(
              child: SizedBox(
                height: screenHeight,
                child: Column(
                  children: [
                    // Header bar
                    Container(
                      height: 64,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      alignment: Alignment.centerLeft,
                      child: title,
                    ),

                    // Main content with proper padding
                    Expanded(
                      child: Material(
                        color: Theme.of(context).colorScheme.background,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: SingleChildScrollView(
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
