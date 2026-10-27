import AppKit
import SwiftUI

@MainActor
final class CapsulePanel {
    private let panel: NSPanel
    private let state: CapsuleState
    private static let size = NSSize(width: 700, height: 260)

    init(state: CapsuleState) {
        self.state = state

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let host = NSHostingView(rootView: CapsuleRoot(state: state))
        host.frame = NSRect(origin: .zero, size: Self.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    func show() {
        placeOnActiveScreen()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    // ставим над Dock по центру того экрана, где сейчас курсор, либо прямо под курсором
    private func placeOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        var x = frame.midX - Self.size.width / 2
        var y = frame.minY + 10

        if Settings.shared.anchor == .cursor {
            x = mouse.x - Self.size.width / 2
            y = mouse.y - Self.size.height - 6
            x = min(max(x, frame.minX + 8), frame.maxX - Self.size.width - 8)
            y = min(max(y, frame.minY + 8), frame.maxY - Self.size.height - 8)
        }

        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }
}

private struct CapsuleRoot: View {
    @ObservedObject var state: CapsuleState

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            CapsuleView(state: state)
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 46)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
