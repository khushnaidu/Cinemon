import UIKit
import Flutter
import Photos

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
      registrar(forPlugin: "LiquidGlassButton")?.register(
        LiquidGlassButtonFactory(messenger: controller.binaryMessenger),
        withId: "cinemon/liquid_glass_button"
      )
      StoryShareChannel.register(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Share cards straight to an Instagram or Facebook story, or into Photos
/// (ADR 0003, D2). Both apps read the story off the general pasteboard under
/// their own keys, then open from their URL scheme; the schemes are listed
/// in Info.plist's LSApplicationQueriesSchemes so canOpenURL can see them.
enum StoryShareChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.35mm/story_share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "canShare":
        guard let url = composerURL(args["target"] as? String, appId: "0") else {
          result(false)
          return
        }
        result(UIApplication.shared.canOpenURL(url))
      case "share":
        share(args, result: result)
      case "saveImage":
        save(args, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func composerURL(_ target: String?, appId: String) -> URL? {
    let scheme: String
    switch target {
    case "instagram": scheme = "instagram-stories"
    case "facebook": scheme = "facebook-stories"
    default: return nil
    }
    return URL(string: "\(scheme)://share?source_application=\(appId)")
  }

  private static func share(_ args: [String: Any], result: @escaping FlutterResult) {
    let target = args["target"] as? String
    guard let appId = args["appId"] as? String,
          let url = composerURL(target, appId: appId),
          UIApplication.shared.canOpenURL(url) else {
      result(false)
      return
    }
    let prefix = target == "facebook" ? "com.facebook.sharedSticker" : "com.instagram.sharedSticker"
    var item: [String: Any] = [:]
    if let bg = (args["background"] as? FlutterStandardTypedData)?.data {
      item["\(prefix).backgroundImage"] = bg
    }
    if let sticker = (args["sticker"] as? FlutterStandardTypedData)?.data {
      item["\(prefix).stickerImage"] = sticker
    }
    if let top = args["top"] as? String { item["\(prefix).backgroundTopColor"] = top }
    if let bottom = args["bottom"] as? String { item["\(prefix).backgroundBottomColor"] = bottom }
    if target == "facebook" { item["com.facebook.sharedSticker.appID"] = appId }
    // The link sticker experiment (ADR 0003, D3): leave the post's link on
    // the pasteboard as text, where the sticker's paste field can find it.
    if let link = args["link"] as? String { item["public.utf8-plain-text"] = link }

    UIPasteboard.general.setItems(
      [item],
      options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
    )
    UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
  }

  private static func save(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let data = (args["png"] as? FlutterStandardTypedData)?.data else {
      result("failed")
      return
    }
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async { result("denied") }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
      }) { ok, _ in
        DispatchQueue.main.async { result(ok ? "saved" : "failed") }
      }
    }
  }
}
