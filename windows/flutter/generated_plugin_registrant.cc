//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_desktop_sleep/flutter_desktop_sleep_plugin_c_api.h>
#include <flutter_window_close/flutter_window_close_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterDesktopSleepPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterDesktopSleepPluginCApi"));
  FlutterWindowClosePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterWindowClosePlugin"));
}
