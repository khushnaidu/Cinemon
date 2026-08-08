import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      registrar(forPlugin: "LiquidGlassTabBar")?.register(
        LiquidGlassTabBarFactory(messenger: controller.binaryMessenger),
        withId: "cinemon/liquid_glass_tab_bar"
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
