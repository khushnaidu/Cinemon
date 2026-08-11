import Flutter
import SwiftUI
import UIKit

// A circular Liquid Glass button, embedded into Flutter as a platform view.
//
// Same reasoning as LiquidGlassTabBar: only the native material refracts, so
// content passing under these buttons actually bends. That is the whole point
// of floating them over the feed instead of parking them in an app bar.
//
// The badge is drawn here rather than in Flutter because a platform view
// composites above the Flutter layer — a Dart badge positioned over one would
// be hidden behind it. Its count arrives over the method channel.

/// Bridges channel messages into SwiftUI state.
final class GlassButtonModel: ObservableObject {
    @Published var badge: Int = 0
}

/// Shared geometry so the iOS 26 and fallback views agree on proportions.
private enum ButtonMetrics {
    /// Margin between the tappable circle and the platform view's bounds.
    /// The badge lives in this gutter — a UIHostingController's view can clip,
    /// so nothing is allowed to overhang.
    static let gutter: CGFloat = 10

    static func diameter(for size: CGSize) -> CGFloat {
        max(0, min(size.width, size.height) - gutter)
    }
}

@available(iOS 26.0, *)
struct LiquidGlassButtonView: View {
    let systemImage: String
    let label: String
    @ObservedObject var model: GlassButtonModel
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let d = ButtonMetrics.diameter(for: geo.size)

            // Glass first, glyph second. Applying the material to a shape that
            // also carries the icon composites the icon underneath it — the
            // same trap that made the tab bar's icons disappear.
            ZStack {
                Color.clear
                    .frame(width: d, height: d)
                    .glassEffect(.regular.tint(.black.opacity(0.35)).interactive(),
                                 in: .circle)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTap()
                } label: {
                    Image(systemName: systemImage)
                        .font(.system(size: d * 0.40, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: d, height: d)
                        .contentShape(Circle())
                        .accessibilityLabel(label)
                }
                .buttonStyle(.plain)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .overlay(alignment: .topTrailing) {
                if model.badge > 0 {
                    BadgeView(count: model.badge)
                }
            }
        }
    }
}

/// Unread count. Sized to sit in the gutter, so it reads as attached to the
/// circle's upper-right without ever leaving the view's bounds.
struct BadgeView: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Color(red: 1.0, green: 0.27, blue: 0.23), in: .capsule)
            .transition(.scale.combined(with: .opacity))
    }
}

/// Pre-iOS 26 fallback: translucent rather than refractive.
struct LegacyBlurButtonView: View {
    let systemImage: String
    let label: String
    @ObservedObject var model: GlassButtonModel
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let d = ButtonMetrics.diameter(for: geo.size)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: d * 0.40, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: d, height: d)
                    .background(.ultraThinMaterial, in: .circle)
                    .overlay(Circle().fill(.black.opacity(0.25)))
                    .clipShape(.circle)
                    .contentShape(Circle())
                    .accessibilityLabel(label)
            }
            .buttonStyle(.plain)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .overlay(alignment: .topTrailing) {
                if model.badge > 0 {
                    BadgeView(count: model.badge)
                }
            }
        }
    }
}

// MARK: - Platform view

final class LiquidGlassButtonPlatformView: NSObject, FlutterPlatformView {
    private let container: UIView
    private let channel: FlutterMethodChannel
    private let model: GlassButtonModel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "cinemon/liquid_glass_button_\(viewId)",
            binaryMessenger: messenger
        )

        let params = args as? [String: Any] ?? [:]
        let systemImage = params["icon"] as? String ?? "circle"
        let label = params["label"] as? String ?? ""

        model = GlassButtonModel()
        model.badge = params["badge"] as? Int ?? 0

        let localChannel = channel
        let onTap: () -> Void = { localChannel.invokeMethod("onTap", arguments: nil) }

        let host: UIViewController
        if #available(iOS 26.0, *) {
            host = UIHostingController(
                rootView: LiquidGlassButtonView(systemImage: systemImage,
                                                label: label,
                                                model: model,
                                                onTap: onTap)
            )
        } else {
            host = UIHostingController(
                rootView: LegacyBlurButtonView(systemImage: systemImage,
                                               label: label,
                                               model: model,
                                               onTap: onTap)
            )
        }

        // Transparent, or it paints over the Flutter content the glass samples.
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.frame = frame
        container = host.view

        super.init()

        let localModel = model
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setBadge":
                if let n = call.arguments as? Int, n != localModel.badge {
                    withAnimation(.snappy(duration: 0.25)) { localModel.badge = n }
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { container }
}

final class LiquidGlassButtonFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect,
                viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        LiquidGlassButtonPlatformView(frame: frame,
                                      viewId: viewId,
                                      args: args,
                                      messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
