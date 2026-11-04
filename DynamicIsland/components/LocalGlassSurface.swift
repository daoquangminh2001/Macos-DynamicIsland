import SwiftUI
import Defaults

enum LocalGlassStyle: String, CaseIterable, Defaults.Serializable {
    case off, soft, semi

    var title: String {
        switch self {
        case .off: return "Tắt"
        case .soft: return "Kính mềm"
        case .semi: return "Semi Glass"
        }
    }
}

struct LocalGlassSurface<Surface: Shape>: View {
    let shape: Surface
    @Default(.enableLocalGlass) private var enabled
    @Default(.localGlassStyle) private var style
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !enabled || style == .off || reduceTransparency {
                shape.fill(Color.black.opacity(0.96))
            } else {
                softGlass
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                stops: style == .semi
                                    ? [.init(color: .black, location: 0),
                                       .init(color: .black, location: 0.20),
                                       .init(color: .black.opacity(0.50), location: 0.55),
                                       .init(color: .clear, location: 1)]
                                    : [.init(color: .black.opacity(0.20), location: 0),
                                       .init(color: .black.opacity(0.14), location: 0.5),
                                       .init(color: .black.opacity(0.24), location: 1)],
                                startPoint: style == .semi ? .top : .topLeading,
                                endPoint: style == .semi ? .bottom : .bottomTrailing
                            )
                        )
                    }
                    .overlay {
                        shape.stroke(
                            LinearGradient(
                                colors: style == .semi
                                    ? [.white.opacity(0.12), .white.opacity(0.03), .clear]
                                    : [.white.opacity(0.65), .white.opacity(0.10), .white.opacity(0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: style == .semi ? 0.7 : 0.8
                        )
                    }
                    .clipShape(shape)
            }
        }
        .mask {
            if enabled && style == .semi && !reduceTransparency {
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.45),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            } else {
                Color.black
            }
        }
        .id(style)
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: style)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: enabled)
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var softGlass: some View {
        if style == .semi {
            if #available(macOS 26.0, *) {
                LocalSoftGlassBackdrop(opacity: 0.38)
                    .glassEffect(.clear.tint(.white.opacity(0.06)), in: shape)
            } else {
                LocalSoftGlassBackdrop(opacity: 0.38)
                    .clipShape(shape)
            }
        } else if #available(macOS 26.0, *) {
            LocalSoftGlassBackdrop()
                .glassEffect(.clear, in: shape)
        } else {
            LocalSoftGlassBackdrop()
                .clipShape(shape)
        }
    }
}

private struct LocalSoftGlassBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .titlebar
    var opacity: CGFloat = 0.22

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Sample the desktop behind this transparent window, without the dense HUD tint.
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = opacity
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.alphaValue = opacity
    }
}
