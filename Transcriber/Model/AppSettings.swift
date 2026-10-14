import Foundation
import Observation

/// App-wide preferences, backed by UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var localeIdentifier: String {
        didSet { defaults.set(localeIdentifier, forKey: "localeIdentifier") }
    }
    var maxCharactersPerLine: Int {
        didSet { defaults.set(maxCharactersPerLine, forKey: "maxCharactersPerLine") }
    }
    var maxLines: Int {
        didSet { defaults.set(maxLines, forKey: "maxLines") }
    }
    var maxCueDuration: Double {
        didSet { defaults.set(maxCueDuration, forKey: "maxCueDuration") }
    }
    var pauseBreak: Double {
        didSet { defaults.set(pauseBreak, forKey: "pauseBreak") }
    }
    var paragraphGap: Double {
        didSet { defaults.set(paragraphGap, forKey: "paragraphGap") }
    }
    var followPlayback: Bool {
        didSet { defaults.set(followPlayback, forKey: "followPlayback") }
    }
    /// Draw the current cue over the video in the player.
    var previewCaptions: Bool {
        didSet { defaults.set(previewCaptions, forKey: "previewCaptions") }
    }
    var captionStyle: CaptionPreviewStyle {
        didSet { defaults.set(captionStyle.rawValue, forKey: "captionStyle") }
    }
    /// Export formats written for files from watched folders (ExportFormat raw values).
    var watchFormats: Set<String> {
        didSet { defaults.set(Array(watchFormats).sorted(), forKey: "watchFormats") }
    }
    /// Also save a .transcriber project next to files from watched folders.
    var watchSavesProject: Bool {
        didSet { defaults.set(watchSavesProject, forKey: "watchSavesProject") }
    }

    /// Export formats written next to each file in the batch window (ExportFormat raw values).
    var batchFormats: Set<String> {
        didSet { defaults.set(Array(batchFormats).sorted(), forKey: "batchFormats") }
    }
    /// Also save a .transcriber project next to each batch file, so it can be opened and edited.
    var batchSavesProject: Bool {
        didSet { defaults.set(batchSavesProject, forKey: "batchSavesProject") }
    }

    private init() {
        localeIdentifier = LanguageCatalog.normalized(defaults.string(forKey: "localeIdentifier") ?? Locale.current.identifier)
        maxCharactersPerLine = defaults.object(forKey: "maxCharactersPerLine") as? Int ?? 42
        maxLines = defaults.object(forKey: "maxLines") as? Int ?? 2
        maxCueDuration = defaults.object(forKey: "maxCueDuration") as? Double ?? 6
        pauseBreak = defaults.object(forKey: "pauseBreak") as? Double ?? 1.0
        paragraphGap = defaults.object(forKey: "paragraphGap") as? Double ?? 1.5
        followPlayback = defaults.object(forKey: "followPlayback") as? Bool ?? true
        previewCaptions = defaults.object(forKey: "previewCaptions") as? Bool ?? true
        captionStyle = CaptionPreviewStyle(rawValue: defaults.string(forKey: "captionStyle") ?? "") ?? .classic
        watchFormats = Set(defaults.stringArray(forKey: "watchFormats") ?? [ExportFormat.srt.rawValue])
        watchSavesProject = defaults.object(forKey: "watchSavesProject") as? Bool ?? false
        batchFormats = Set(defaults.stringArray(forKey: "batchFormats") ?? [ExportFormat.srt.rawValue, ExportFormat.text.rawValue])
        batchSavesProject = defaults.object(forKey: "batchSavesProject") as? Bool ?? true
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    var cueSettings: CueSettings {
        CueSettings(maxCharactersPerLine: maxCharactersPerLine, maxLines: maxLines,
                    maxDuration: maxCueDuration, pauseBreak: pauseBreak)
    }
}
