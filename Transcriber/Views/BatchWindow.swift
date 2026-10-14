import AppKit
import SwiftUI

/// The single batch window, shown whenever more than one media file arrives at once.
@MainActor
enum BatchWindow {
    private static var window: NSWindow?

    static func show(adding urls: [URL] = []) {
        if !urls.isEmpty { BatchQueue.shared.add(urls) }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Batch Transcription"
            window.contentView = NSHostingView(rootView: BatchView())
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("BatchTranscription")
            if window.frame.origin == .zero { window.center() }
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Gives a SwiftUI view the NSWindow it lives in.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
