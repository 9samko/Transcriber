import AppKit
import Foundation
import Observation

/// One file in the batch window.
struct BatchItem: Identifiable, Hashable {
    enum Status: Hashable {
        case waiting
        case running
        case done
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let url: URL
    var status: Status = .waiting
    var progress: Double = 0
    var detail = ""
    /// The files written for this item, the project first when one was saved.
    var outputs: [URL] = []

    var fileName: String { url.lastPathComponent }

    var isFinished: Bool {
        switch status {
        case .done, .failed, .cancelled: true
        default: false
        }
    }
}

/// Several media files dropped at once go here instead of one window each. They are transcribed
/// one after another and the outputs chosen in the batch window are written next to each file.
@MainActor @Observable
final class BatchQueue {
    static let shared = BatchQueue()

    private(set) var items: [BatchItem] = []
    private(set) var isRunning = false

    @ObservationIgnored private var current: Task<[URL], Error>?
    @ObservationIgnored private var currentID: UUID?

    private init() {}

    var finishedCount: Int { items.filter(\.isFinished).count }
    var failedCount: Int { items.filter { if case .failed = $0.status { true } else { false } }.count }

    /// Overall progress: finished files count whole, the running one by its own progress.
    var overallProgress: Double {
        guard !items.isEmpty else { return 0 }
        let running = items.first { $0.status == .running }?.progress ?? 0
        return (Double(finishedCount) + running) / Double(items.count)
    }

    func add(_ urls: [URL]) {
        let known = Set(items.filter { !$0.isFinished }.map(\.url))
        for url in urls where !known.contains(url) {
            items.append(BatchItem(url: url))
        }
        startIfNeeded()
    }

    func remove(_ id: UUID) {
        if id == currentID { cancelCurrent() }
        items.removeAll { $0.id == id }
    }

    func clearFinished() {
        items.removeAll(where: \.isFinished)
    }

    func retry(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isFinished else { return }
        items[index].status = .waiting
        items[index].progress = 0
        items[index].detail = ""
        items[index].outputs = []
        startIfNeeded()
    }

    func cancelCurrent() {
        current?.cancel()
    }

    /// Stops the running file and marks everything still waiting as cancelled.
    func cancelAll() {
        for index in items.indices where items[index].status == .waiting {
            items[index].status = .cancelled
        }
        current?.cancel()
    }

    private func startIfNeeded() {
        guard !isRunning else { return }
        isRunning = true
        Task { await run() }
    }

    private func run() async {
        defer {
            isRunning = false
            currentID = nil
            current = nil
        }
        var processed = 0
        while let index = items.firstIndex(where: { $0.status == .waiting }) {
            let id = items[index].id
            let url = items[index].url
            let settings = AppSettings.shared
            let formats = settings.batchFormats
            let savesProject = settings.batchSavesProject
            currentID = id
            update(id) { $0.status = .running; $0.detail = "Starting…" }
            let task = Task { [weak self] in
                try await WatchProcessor.transcribe(url, formats: formats, savesProject: savesProject) { event in
                    self?.handle(event, for: id)
                }
            }
            current = task
            do {
                let outputs = try await task.value
                update(id) { $0.status = .done; $0.progress = 1; $0.outputs = outputs; $0.detail = "" }
            } catch {
                let cancelled = error is CancellationError || task.isCancelled
                update(id) {
                    $0.status = cancelled ? .cancelled : .failed(error.localizedDescription)
                    $0.detail = ""
                }
            }
            processed += 1
        }
        if processed > 1, NSApp?.isActive == false {
            let failed = failedCount
            Notifier.post(title: "Batch transcription finished",
                          body: failed == 0 ? "\(items.count) files transcribed." : "\(items.count - failed) transcribed, \(failed) failed.",
                          fileURL: items.last?.outputs.first)
        }
    }

    private func handle(_ event: TranscriptionEvent, for id: UUID) {
        update(id) { item in
            switch event {
            case .status(let text):
                item.detail = text
            case .downloading(let fraction):
                item.detail = "Downloading speech model… \(Int(fraction * 100))%"
            case .progress(let fraction):
                item.progress = max(item.progress, fraction)
                item.detail = "Transcribing… \(Int(item.progress * 100))%"
            case .volatile, .words:
                break
            }
        }
    }

    private func update(_ id: UUID, _ change: (inout BatchItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }
}
