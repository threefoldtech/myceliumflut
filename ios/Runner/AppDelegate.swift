import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let tunChannel = FlutterMethodChannel(name: "tech.threefold.mycelium/tun",
                                              binaryMessenger: controller.binaryMessenger)
    tunChannel.setMethodCallHandler({
        [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
          // This method is invoked on the UI thread.
          guard call.method == "getBatteryLevel" else {
            result(FlutterMethodNotImplemented)
            return
          }
          result(90)
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
