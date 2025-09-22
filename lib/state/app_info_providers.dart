import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provider for app version information
final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return 'v${packageInfo.version}';
});

/// Provider for app build number
final appBuildNumberProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.buildNumber;
});

/// Provider for full app version (version + build)
final fullAppVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return 'v${packageInfo.version}+${packageInfo.buildNumber}';
});
