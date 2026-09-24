import UIKit
import Flutter
import MessageUI
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

/// Share cards straight to an Instagram, Facebook or Snapchat story, a
/// message, or Photos (ADR 0003, D2). The three apps read the card off the
/// general pasteboard under their own keys, then open from their URL scheme;
/// the schemes are listed in Info.plist's LSApplicationQueriesSchemes so
/// canOpenURL can see them.
enum StoryShareChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.35mm/story_share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "canShare":
        let target = args["target"] as? String
        if target == "messages" {
          result(MFMessageComposeViewController.canSendText()
            && MFMessageComposeViewController.canSendAttachments())
          return
        }
        let url = target == "snapchat"
          ? URL(string: snapchatPreview)
          : composerURL(target, appId: "0")
        result(url.map { UIApplication.shared.canOpenURL($0) } ?? false)
      case "share":
        share(args, result: result)
      case "snapchat":
        snapchat(args, result: result)
      case "message":
        MessageComposer.shared.present(args, result: result)
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

  /// Snapchat's Creative Kit Lite: the card as the Snap, the link as its
  /// caption. Snapchat checks the pasteboard's change count against the one
  /// in the URL, so the URL is built after the pasteboard is set.
  private static let snapchatPreview = "snapchat://creativekit/preview/1"

  private static func snapchat(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let clientId = args["clientId"] as? String,
          let image = (args["background"] as? FlutterStandardTypedData)?.data,
          var components = URLComponents(string: snapchatPreview),
          let probe = components.url,
          UIApplication.shared.canOpenURL(probe) else {
      result(false)
      return
    }
    var item: [String: Any] = [
      "com.snapchat.creativekit.clientID": clientId,
      "com.snapchat.creativekit.backgroundImage": image,
    ]
    if let caption = args["caption"] as? String {
      item["com.snapchat.creativekit.captionText"] = caption
    }
    UIPasteboard.general.setItems(
      [item],
      options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
    )
    components.queryItems = [
      URLQueryItem(name: "checkcount", value: String(UIPasteboard.general.changeCount)),
      URLQueryItem(name: "clientId", value: clientId),
      URLQueryItem(name: "appDisplayName", value: "35mm"),
    ]
    guard let url = components.url else {
      result(false)
      return
    }
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

/// The system message composer with the card attached and the link as the
/// text. Held as a singleton because the composer keeps only a weak
/// reference to its delegate.
final class MessageComposer: NSObject, MFMessageComposeViewControllerDelegate {
  static let shared = MessageComposer()

  private var pending: FlutterResult?

  func present(_ args: [String: Any], result: @escaping FlutterResult) {
    guard pending == nil,
          MFMessageComposeViewController.canSendText(),
          let presenter = Self.topController() else {
      result("failed")
      return
    }
    let composer = MFMessageComposeViewController()
    composer.messageComposeDelegate = self
    if let body = args["body"] as? String { composer.body = body }
    if let png = (args["png"] as? FlutterStandardTypedData)?.data {
      composer.addAttachmentData(png, typeIdentifier: "public.png", filename: "35mm.png")
    }
    pending = result
    presenter.present(composer, animated: true)
  }

  func messageComposeViewController(
    _ controller: MFMessageComposeViewController,
    didFinishWith outcome: MessageComposeResult
  ) {
    controller.dismiss(animated: true)
    let result = pending
    pending = nil
    switch outcome {
    case .sent: result?("sent")
    case .cancelled: result?("cancelled")
    default: result?("failed")
    }
  }

  private static func topController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let next = top?.presentedViewController { top = next }
    return top
  }
}
