import AppKit
import SwiftUI

/// The batch window: every file dropped together is listed here and transcribed one after another,
/// with an overall status bar instead of a window per file.
struct BatchView: View {
    @Bindable private var queue = BatchQueue.shared
    @Bindable private var settings = AppSettings.shared
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if queue.items.isEmpty {
                empty
            } else {
                List {
                    ForEach(queue.items) { item in
                        BatchRow(item: item)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 380)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let media = urls.filter { PendingMedia.isMedia($0) }
            queue.add(media)
            return !media.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if queue.isRunning {
                    Button("Stop All") { queue.cancelAll() }
                }
            }
            ProgressView(value: queue.overallProgress)
                .progressViewStyle(.linear)
        }
        .padding(16)
    }

    private var title: String {
        let total = queue.items.count
        if total == 0 { return "Batch Transcription" }
        if queue.isRunning {
            return "Transcribing \(min(queue.finishedCount + 1, total)) of \(total)"
        }
        return "\(queue.finishedCount) of \(total) finished"
    }

    private var subtitle: String {
        let failed = queue.failedCount
        var parts = ["\(Int(queue.overallProgress * 100))% overall"]
        if failed > 0 { parts.append("\(failed) failed") }
        if let running = queue.items.first(where: { $0.status == .running }) {
            parts.append(running.fileName)
        }
        return parts.joined(separator: " · ")
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop video or audio files here")
                .font(.title3.weight(.semibold))
            Text("They are transcribed one after another and the results are saved next to each file.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Add Files…", action: addFiles)
                .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("Save:")
                .foregroundStyle(.secondary)
            Toggle("Project", isOn: $settings.batchSavesProject)
                .help("A .transcriber project you can open to review and edit the transcript")
            Menu(formatsLabel) {
                ForEach(ExportFormat.allCases) { format in
                    Toggle(format.title, isOn: Binding(
                        get: { settings.batchFormats.contains(format.rawValue) },
                        set: { on in
                            if on { settings.batchFormats.insert(format.rawValue) } else { settings.batchFormats.remove(format.rawValue) }
                        }))
                }
            }
            .fixedSize()
            LanguagePicker(selection: $settings.localeIdentifier)
                .labelsHidden()
                .fixedSize()
                .help("The language of the speech in the files")
            Spacer()
            Button("Add Files…", action: addFiles)
            Button("Clear Finished") { queue.clearFinished() }
                .disabled(queue.finishedCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .font(.callout)
    }

    private var formatsLabel: String {
        let chosen = ExportFormat.allCases.filter { settings.batchFormats.contains($0.rawValue) }
        if chosen.isEmpty { return "No exports" }
        return chosen.map { $0 == .text ? "TXT" : $0 == .timestampedText ? "TXT+time" : $0 == .markdown ? "MD" : $0 == .soap ? "SOAP" : $0.rawValue.uppercased() }
            .joined(separator: ", ")
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = PendingMedia.acceptedTypes
        panel.message = "Choose video or audio files to transcribe."
        guard panel.runModal() == .OK else { return }
        queue.add(panel.urls)
    }
}

private struct BatchRow: View {
    let item: BatchItem
    private var queue: BatchQueue { BatchQueue.shared }

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if item.status == .running {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .monospacedDigit()
            }
            Spacer()
            actions
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(item.outputs.isEmpty ? [item.url] : item.outputs)
            }
            Button("Remove from List") { queue.remove(item.id) }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch item.status {
        case .waiting:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .cancelled:
            Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch item.status {
        case .waiting:
            Button { queue.remove(item.id) } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Remove from the queue")
        case .running:
            Button("Cancel") { queue.cancelCurrent() }
        case .done:
            if let project = item.outputs.first(where: PendingMedia.isProject) {
                Button("Open") {
                    NSDocumentController.shared.openDocument(withContentsOf: project, display: true) { _, _, _ in }
                }
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting(item.outputs.isEmpty ? [item.url] : item.outputs)
            } label: { Image(systemName: "folder") }
                .buttonStyle(.borderless)
                .help("Show in Finder")
        case .failed, .cancelled:
            Button("Retry") { queue.retry(item.id) }
        }
    }

    private var statusText: String {
        switch item.status {
        case .waiting: "Waiting"
        case .running: item.detail.isEmpty ? "Transcribing…" : item.detail
        case .done: item.outputs.isEmpty ? "Done (nothing chosen to save)" : "Saved " + item.outputs.map(\.lastPathComponent).joined(separator: ", ")
        case .failed(let message): message
        case .cancelled: "Cancelled"
        }
    }

    private var statusColor: Color {
        if case .failed = item.status { return .orange }
        return .secondary
    }
}
