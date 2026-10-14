import AVFoundation
import Foundation

/// What Transcriber does with a file that lands in a watched folder: transcribe it and write the
/// outputs chosen in Settings next to it. Returns the first file written, for the notification.
@MainActor
enum WatchProcessor {
    static func accepts(_ url: URL) -> Bool {
        PendingMedia.isMedia(url)
    }

    static func transcribe(_ url: URL) async throws -> URL? {
        let settings = AppSettings.shared
        return try await transcribe(url, formats: settings.watchFormats, savesProject: settings.watchSavesProject).first
    }

    /// Transcribes `url` and writes the given export formats (ExportFormat raw values) and, if asked,
    /// a .transcriber project next to it. Returns the files written, the project first.
    static func transcribe(_ url: URL, formats: Set<String>, savesProject: Bool,
                           onEvent: (TranscriptionEvent) -> Void = { _ in }) async throws -> [URL] {
        let settings = AppSettings.shared
        let locale = settings.locale
        let cueSettings = settings.cueSettings
        var words: [TranscriptWord] = []
        for try await event in TranscriptionEngine.transcribe(url: url, locale: locale) {
            if case .words(let new) = event { words.append(contentsOf: new) }
            onEvent(event)
        }
        try Task.checkCancellation()
        let cues = CueBuilder.cues(from: words, settings: cueSettings)
        let base = url.deletingPathExtension()
        let title = base.lastPathComponent
        var written: [URL] = []

        for format in ExportFormat.allCases where formats.contains(format.rawValue) {
            let text: String
            if format.isGenerated {
                onEvent(.status("Writing SOAP note…"))
                let transcript = TranscriptExporter.plainText(cues, paragraphGap: settings.paragraphGap)
                text = try await SoapNoteGenerator.generate(transcript: transcript, title: title)
            } else {
                text = TranscriptExporter.export(cues, as: format, title: title, cueSettings: cueSettings, paragraphGap: settings.paragraphGap)
            }
            let target = uniqueURL(base: format.fileSuffix.isEmpty ? base : base.deletingLastPathComponent().appendingPathComponent(base.lastPathComponent + format.fileSuffix),
                                   ext: format.fileExtension)
            try text.write(to: target, atomically: true, encoding: .utf8)
            written.append(target)
        }

        if savesProject {
            let duration = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            let file = ProjectFile(mediaBookmark: try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
                                   mediaPath: url.path,
                                   mediaFileName: url.lastPathComponent,
                                   mediaDuration: duration,
                                   transcript: Transcript(words: words, cues: cues, localeIdentifier: locale.identifier, createdAt: Date()),
                                   cueSettings: cueSettings)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let target = uniqueURL(base: base, ext: "transcriber")
            try encoder.encode(file).write(to: target, options: .atomic)
            written.insert(target, at: 0)
        }
        return written
    }

    /// `Talk.srt`, or `Talk 2.srt` if that already exists: nothing the user made gets overwritten.
    private static func uniqueURL(base: URL, ext: String) -> URL {
        var candidate = base.appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = base.deletingLastPathComponent()
                .appendingPathComponent("\(base.lastPathComponent) \(n)")
                .appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}
