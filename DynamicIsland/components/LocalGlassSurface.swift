import SwiftUI
import Defaults

struct LocalGlassSurface<Surface: Shape>: View {
    let shape: Surface
    @Default(.enableLocalGlass) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if !enabled || reduceTransparency {
                shape.fill(Color.black.opacity(0.96))
            } else {
                softGlass
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [.black.opacity(0.20), .black.opacity(0.14), .black.opacity(0.24)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    }
                    .overlay {
                        shape.stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.65), .white.opacity(0.10), .white.opacity(0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                    }
                    .clipShape(shape)
            }
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var softGlass: some View {
        if #available(macOS 26.0, *) {
            LocalSoftGlassBackdrop()
                .glassEffect(.clear, in: shape)
        } else {
            LocalSoftGlassBackdrop()
                .clipShape(shape)
        }
    }
}

private struct LocalSoftGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Sample the desktop behind this transparent window, without the dense HUD tint.
        view.material = .titlebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = 0.22
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
