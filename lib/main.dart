import 'package:flutter/material.dart';
import 'app/theme/app_theme.dart';
import 'app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/app_settings.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:flutter_desktop_sleep/flutter_desktop_sleep.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_alone/flutter_alone.dart';

import 'services/ffi/mycelium_service.dart';
import 'myceliumflut_ffi_binding.dart';
import 'app/router/app_router.dart' as router_export;

final _logger = Logger('Mycelium');

Future<void> main() async {
  // Logger configuration
  Logger.root.level = Level.ALL; // Log messages emitted at all levels
  Logger.root.onRecord.listen((record) {
    // we need this to print to the console
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Single instance check for desktop platforms
  if (Platform.isMacOS || Platform.isWindows) {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure single instance settings
    FlutterAloneConfig? config;
    if (Platform.isWindows) {
      config = FlutterAloneConfig.forWindows(
        windowsConfig: const DefaultWindowsMutexConfig(
          packageId: 'tech.threefold.mycelium',
          appName: 'Mycelium',
        ),
        messageConfig: const EnMessageConfig(),
      );
    } else if (Platform.isMacOS) {
      config = FlutterAloneConfig.forMacOS(
        macOSConfig: const MacOSConfig(
          lockFileName: 'mycelium.lock',
        ),
        messageConfig: const EnMessageConfig(),
      );
    }

    // Check for duplicate instance and exit if another is running
    if (config != null &&
        !await FlutterAlone.instance.checkAndRun(config: config)) {
      _logger.info(
          'Another instance of Mycelium is already running. Focusing existing window...');
      // Exit this instance - flutter_alone will focus the existing window
      exit(0);
    }

    _logger.info('First instance of Mycelium starting...');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with TrayListener, WindowListener, WidgetsBindingObserver {
  static const platform = MethodChannel("tech.threefold.mycelium/tun");
  final _flutterDesktopSleepPlugin = FlutterDesktopSleep();
  final MyceliumService _myceliumService = MyceliumService();
  bool _hasShownAdminWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    platform.setMethodCallHandler((MethodCall call) async {});
    // Initialize desktop lifecycle asynchronously to avoid blocking startup
    Future.delayed(const Duration(seconds: 1), () => _initDesktopLifecycle());
  }

  Future<void> _initDesktopLifecycle() async {
    if (!(Platform.isMacOS || Platform.isWindows)) {
      return;
    }

    try {
      _logger.info("Initializing desktop lifecycle...");

      // Initialize window manager
      await windowManager.ensureInitialized();
      _logger.info("Window manager ensureInitialized completed");

      windowManager.addListener(this);
      _logger.info("Window manager listener added");

      await windowManager.setPreventClose(true);
      _logger.info("Window manager setPreventClose completed");

      // Configure window properties
      await windowManager.setTitle('Mycelium');
      _logger.info("Window manager setTitle completed");

      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      _logger.info("Window manager setTitleBarStyle completed");

      // Set window size to 1200px width with appropriate height
      await windowManager.setSize(const Size(1200, 800));
      await windowManager.center();
      _logger.info("Window manager setSize and center completed");

      // Check for administrator privileges on Windows after UI is ready
      if (Platform.isWindows) {
        Future.delayed(const Duration(seconds: 2), () {
          _checkAdminPrivileges();
        });
      }

      // Initialize tray manager with careful error handling
      try {
        _logger.info("Starting tray manager initialization...");
        trayManager.addListener(this);
        _logger.info("Tray manager listener added successfully");

        // Try different icon paths in order of preference
        final iconPath = Platform.isWindows
            ? 'assets/images/tray_icon.ico'
            : Platform.isMacOS
                ? 'assets/images/tray_icon_macos.png'
                : 'assets/images/mycelium_icon.png';

        try {
          await trayManager.setIcon(iconPath);
          _logger.info("Tray icon set successfully using: $iconPath");
        } catch (e) {
          _logger.warning("Failed to set tray icon from $iconPath: $e");
          // Try fallback icon for macOS
          if (Platform.isMacOS) {
            try {
              await trayManager.setIcon('assets/images/mycelium_icon.png');
              _logger.info("Tray icon set using fallback: mycelium_icon.png");
            } catch (fallbackError) {
              _logger
                  .severe("Failed to set fallback tray icon: $fallbackError");
            }
          }
        }

        // Set tray tooltip
        await trayManager.setToolTip('Mycelium - Click to show/hide window');
        await _updateTrayMenu();
        _logger.info("Tray manager initialized successfully");
      } catch (e) {
        _logger.warning(
            "Failed to initialize tray manager: $e, continuing without tray");
      }

      // Optional: start minimized to tray when app launches on desktop
      // await windowManager.hide();
    } catch (e) {
      _logger.severe("Failed to initialize desktop lifecycle: $e");
      // Don't rethrow - allow app to continue without desktop features
    }
  }

  Future<void> _updateTrayMenu() async {
    try {
      final items = [
        MenuItem(key: 'show', label: 'Show Window'),
        MenuItem(key: 'hide', label: 'Hide Window'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ];
      await trayManager.setContextMenu(Menu(items: items));
    } catch (e) {
      _logger.warning("Failed to update tray menu: $e");
    }
  }

  void _checkAdminPrivileges() {
    if (_hasShownAdminWarning) return;

    try {
      final isAdmin = myFFIsRunningAsAdmin();
      _logger.info("Administrator check: $isAdmin");

      if (!isAdmin && mounted) {
        _hasShownAdminWarning = true;
        _showAdminWarningDialog();
      }
    } catch (e) {
      _logger.warning("Failed to check administrator privileges: $e");
    }
  }

  void _showAdminWarningDialog() {
    final navigatorContext = router_export.rootNavigatorKey.currentContext;
    _logger.info("Attempting to show admin warning dialog...");
    _logger.info("Navigator context available: ${navigatorContext != null}");
    _logger.info("Widget mounted: $mounted");

    if (navigatorContext == null || !mounted) {
      _logger.warning("Cannot show admin warning: context not available");
      return;
    }

    _logger.info("Showing admin warning dialog now");
    showDialog(
      context: navigatorContext,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Important Notice',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mycelium needs special permissions to work properly.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 16),
                Text(
                  'Without these permissions, the app may not be able to:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '• Connect to the Mycelium network',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Enable secure networking features',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  'How to fix this:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Close Mycelium',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '2. Right-click the Mycelium icon',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '3. Choose "Run as administrator"',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    if (Platform.isMacOS || Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      // Release single instance resources
      FlutterAlone.instance.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //_logger.info("ratio: ${MediaQuery.devicePixelRatioOf(context)}");
    final settings = ref.watch(appSettingsProvider).themeMode;
    return MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings,
      routerConfig: appRouter,
    );
  }

  // Window lifecycle handlers
  @override
  void onWindowClose() async {
    // Intercept close to keep app running in tray
    _logger.info("Window close intercepted - hiding to tray");
    await windowManager.hide();
  }

  // Tray handlers
  @override
  void onTrayIconMouseDown() async {
    // On macOS, single click should toggle window visibility
    if (Platform.isMacOS) {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } else {
      await trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    // Right click always shows context menu
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide':
        await windowManager.hide();
        break;
      case 'quit':
        // Stop Mycelium (this will automatically clean up VPN, proxy discovery, and device-wide proxy)
        try {
          await _myceliumService.stop().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _logger.warning('Mycelium stop timed out, forcing exit');
              return false;
            },
          );
        } catch (e) {
          _logger.severe('Error stopping Mycelium: $e');
        }

        // Exit immediately
        exit(0);
    }
  }
}
