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

import 'services/ffi/mycelium_service.dart';

final _logger = Logger('Mycelium');

Future<void> main() async {
  // Logger configuration
  Logger.root.level = Level.ALL; // Log messages emitted at all levels
  Logger.root.onRecord.listen((record) {
    // we need this to print to the console
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
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
              _logger.severe("Failed to set fallback tray icon: $fallbackError");
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

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    if (Platform.isMacOS || Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
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
        _myceliumService.stop();
        // Give a brief moment for stop to propagate
        await Future.delayed(const Duration(milliseconds: 200));
        // Terminate application
        if (Platform.isMacOS) {
          // Use existing plugin to terminate if available
          try {
            _flutterDesktopSleepPlugin.terminateApp();
          } catch (_) {
            exit(0);
          }
        } else {
          exit(0);
        }
        break;
    }
  }
}
