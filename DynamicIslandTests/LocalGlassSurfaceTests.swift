import AppKit
import Defaults
import SwiftUI
import XCTest

@testable import Atoll

@MainActor
final class LocalGlassSurfaceTests: XCTestCase {
    func testSemiDoesNotUseAnOpaqueWindowMaterial() throws {
        try XCTSkipIf(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
        withSurface(style: .semi) { effects in
            XCTAssertFalse(effects.isEmpty)
            for effect in effects {
                XCTAssertEqual(effect.material, .titlebar)
                XCTAssertLessThanOrEqual(effect.alphaValue, 0.4)
            }
        }
    }

    func testOffHasNoBackdrop() {
        withSurface(style: .off) { XCTAssertTrue($0.isEmpty) }
    }

    private func withSurface(style: LocalGlassStyle,
                             check: ([NSVisualEffectView]) -> Void) {
        let oldEnabled = Defaults[.enableLocalGlass]
        let oldStyle = Defaults[.localGlassStyle]
        defer {
            Defaults[.enableLocalGlass] = oldEnabled
            Defaults[.localGlassStyle] = oldStyle
        }
        Defaults[.enableLocalGlass] = true
        Defaults[.localGlassStyle] = style
        let host = NSHostingView(rootView:
            LocalGlassSurface(shape: RoundedRectangle(cornerRadius: 18))
                .transaction { $0.disablesAnimations = true }
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        func effects(in view: NSView) -> [NSVisualEffectView] {
            (view as? NSVisualEffectView).map { [$0] } ?? view.subviews.flatMap { effects(in: $0) }
        }
        check(effects(in: host))
        window.contentView = nil
    }
}
