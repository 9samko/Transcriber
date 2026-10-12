import SwiftUI

/// How captions look when drawn over the video in the player.
nonisolated enum CaptionPreviewStyle: String, CaseIterable, Identifiable, Sendable {
    case classic, boxed, outlined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .boxed: "Boxed"
        case .outlined: "Outlined"
        }
    }

    var summary: String {
        switch self {
        case .classic: "White text with a soft shadow, like broadcast subtitles."
        case .boxed: "White text on a translucent dark panel, like YouTube."
        case .outlined: "Bold white text with a black outline, easy to read on busy video."
        }
    }
}

/// The current cue drawn over the video, in the chosen style. Never intercepts clicks.
struct CaptionOverlay: View {
    let text: String?
    let style: CaptionPreviewStyle
    var scale: CGFloat = 1

    var body: some View {
        VStack {
            Spacer()
            if let text, !text.isEmpty {
                caption(text)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14 * scale)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: text)
    }

    @ViewBuilder
    private func caption(_ text: String) -> some View {
        switch style {
        case .classic:
            Text(text)
                .font(.system(size: 17 * scale, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 2 * scale, x: 0, y: 1 * scale)
                .shadow(color: .black.opacity(0.6), radius: 6 * scale)
                .multilineTextAlignment(.center)
        case .boxed:
            Text(text)
                .font(.system(size: 16 * scale, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10 * scale)
                .padding(.vertical, 5 * scale)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 5 * scale, style: .continuous))
        case .outlined:
            OutlinedText(text, size: 19 * scale, strokeWidth: 1.6 * scale)
        }
    }
}

/// Heavy white text with a black outline, drawn as offset copies behind the text.
struct OutlinedText: View {
    let text: String
    let size: CGFloat
    let strokeWidth: CGFloat

    init(_ text: String, size: CGFloat, strokeWidth: CGFloat) {
        self.text = text
        self.size = size
        self.strokeWidth = strokeWidth
    }

    private var label: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .multilineTextAlignment(.center)
    }

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                label
                    .foregroundStyle(.black)
                    .offset(x: cos(angle) * strokeWidth, y: sin(angle) * strokeWidth)
            }
            label
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }
}

/// A caption rendered over a mock video frame, for the Settings preview.
struct CaptionStyleSample: View {
    let style: CaptionPreviewStyle

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.2, blue: 0.32), Color(red: 0.45, green: 0.3, blue: 0.55), Color(red: 0.2, green: 0.14, blue: 0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 90, height: 90)
                .offset(x: -60, y: -10)
            CaptionOverlay(text: "Drop a video or an audio file,\nand the transcript appears.", style: style, scale: 0.85)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
