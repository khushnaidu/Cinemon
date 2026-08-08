import Flutter
import SwiftUI
import UIKit

// Apple's Liquid Glass, embedded into Flutter as a platform view.
//
// This exists because BackdropFilter cannot refract. It samples the backdrop
// and filters it — blur, saturation, tint — but it cannot *displace* the
// samples, and refraction is displacement: bending coordinates so content
// warps and magnifies near the bevel. A Dart reimplementation can therefore
// get close on colour and never move a single pixel of what's behind it.
//
// The real material also lets neighbouring shapes attract and merge as the
// selection travels, which is GlassEffectContainer's job and likewise not
// reproducible with a filter.
//
// Selection and the compact/expanded state are pushed from Flutter over a
// method channel; taps are handled natively and reported back, so Flutter
// never hit-tests through the platform view.

struct TabItem: Identifiable {
    let id: Int
    let systemImage: String
    let selectedSystemImage: String
    let label: String
}

/// Bridges channel messages into SwiftUI state. Without this the view keeps
/// its own @State and silently ignores Flutter — which is exactly why the
/// first version left the selection stuck on the wrong tab.
final class TabBarModel: ObservableObject {
    @Published var selection: Int
    @Published var compact: Bool = false

    init(selection: Int) {
        self.selection = selection
    }
}

@available(iOS 26.0, *)
struct LiquidGlassTabBarView: View {
    let items: [TabItem]
    @ObservedObject var model: TabBarModel
    let onSelect: (Int) -> Void

    /// Gap between the indicator and the bar's inner edge.
    private let inset: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            // Compact shrinks on both axes. Only losing height made the bar
            // look squashed rather than smaller.
            let width  = model.compact ? fullWidth * 0.68 : fullWidth
            let height: CGFloat = model.compact ? 42 : 56
            let slot   = width / CGFloat(items.count)
            let icon: CGFloat = model.compact ? 16 : 20

            // Three plain layers, no GlassEffectContainer.
            //
            // The container exists to let neighbouring glass shapes attract
            // and merge, and it did: the indicator sits wholly inside the
            // bar, so at spacing 18 the two fused into a single shape and the
            // indicator vanished. It was also hoisting every glass element
            // into one pass that composited above the icons.
            //
            // A single travelling indicator needs neither behaviour, so the
            // glass is applied directly and z-order is just ZStack order:
            // bar, indicator, icons. `.glassEffect` works standalone; the
            // container is only for grouping.
            ZStack(alignment: .leading) {
                // The bar.
                Color.clear
                    .frame(width: width, height: height)
                    .glassEffect(.regular.tint(.black.opacity(0.40)), in: .capsule)

                // The travelling indicator. Tinted light so it reads as a
                // brighter lens against the dark bar rather than disappearing
                // into it, and inset so it sits within the bar.
                Color.clear
                    .frame(width: slot - inset * 2, height: height - inset * 2)
                    .glassEffect(.regular.tint(.white.opacity(0.22)).interactive(),
                                 in: .capsule)
                    .offset(x: slot * CGFloat(model.selection) + inset)

                // Icons last, so they're above both.
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        let isSelected = item.id == model.selection
                        Button {
                            if item.id != model.selection {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                            onSelect(item.id)
                        } label: {
                            Image(systemName: isSelected ? item.selectedSystemImage
                                                         : item.systemImage)
                                .font(.system(size: icon,
                                              weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                                .frame(width: slot, height: height)
                                .contentShape(Rectangle())
                                .accessibilityLabel(item.label)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: width, height: height)
            }
            .frame(width: fullWidth, height: geo.size.height, alignment: .center)
            .animation(.smooth(duration: 0.45, extraBounce: 0.20), value: model.selection)
            .animation(.smooth(duration: 0.32), value: model.compact)
        }
    }
}

/// Pre-iOS 26 fallback so older devices still get floating translucent chrome.
struct LegacyBlurTabBarView: View {
    let items: [TabItem]
    @ObservedObject var model: TabBarModel
    let onSelect: (Int) -> Void

    private var height: CGFloat { model.compact ? 44 : 56 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.id == model.selection
                Button {
                    if item.id != model.selection {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            model.selection = item.id
                        }
                    }
                    onSelect(item.id)
                } label: {
                    Image(systemName: isSelected ? item.selectedSystemImage
                                                 : item.systemImage)
                        .font(.system(size: model.compact ? 17 : 20,
                                      weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background {
                            if isSelected {
                                Capsule().fill(.white.opacity(0.14))
                            }
                        }
                        .contentShape(Rectangle())
                        .accessibilityLabel(item.label)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
        .frame(height: height)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(Capsule().fill(.black.opacity(0.30)))
        .clipShape(.capsule)
    }
}

// MARK: - Platform view

final class LiquidGlassTabBarPlatformView: NSObject, FlutterPlatformView {
    private let container: UIView
    private let channel: FlutterMethodChannel
    private let model: TabBarModel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "cinemon/liquid_glass_tab_bar_\(viewId)",
            binaryMessenger: messenger
        )

        let params = args as? [String: Any] ?? [:]
        let initial = params["initialIndex"] as? Int ?? 0
        let rawItems = params["items"] as? [[String: Any]] ?? []

        let items: [TabItem] = rawItems.enumerated().map { index, dict in
            TabItem(
                id: index,
                systemImage: dict["icon"] as? String ?? "circle",
                selectedSystemImage: dict["activeIcon"] as? String
                    ?? dict["icon"] as? String ?? "circle",
                label: dict["label"] as? String ?? ""
            )
        }

        model = TabBarModel(selection: initial)

        let localChannel = channel
        let onSelect: (Int) -> Void = { index in
            localChannel.invokeMethod("onSelect", arguments: index)
        }

        let host: UIViewController
        if #available(iOS 26.0, *) {
            host = UIHostingController(
                rootView: LiquidGlassTabBarView(items: items, model: model, onSelect: onSelect)
            )
        } else {
            host = UIHostingController(
                rootView: LegacyBlurTabBarView(items: items, model: model, onSelect: onSelect)
            )
        }

        // Must be transparent, or it paints over the Flutter content the
        // glass is supposed to sample.
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.frame = frame
        container = host.view

        super.init()

        let localModel = model
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setIndex":
                // Ignore the echo of a selection this view already made —
                // re-animating an in-flight spring to its own target is what
                // made the blob stutter.
                if let i = call.arguments as? Int, i != localModel.selection {
                    withAnimation(.smooth(duration: 0.42, extraBounce: 0.16)) {
                        localModel.selection = i
                    }
                }
                result(nil)
            case "setCompact":
                if let c = call.arguments as? Bool {
                    localModel.compact = c
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { container }
}

final class LiquidGlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect,
                viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        LiquidGlassTabBarPlatformView(frame: frame,
                                      viewId: viewId,
                                      args: args,
                                      messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
