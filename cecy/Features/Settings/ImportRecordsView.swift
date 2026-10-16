import SwiftUI
import UniformTypeIdentifiers

struct ImportRecordsView: View {
    private static let maximumImportBytes = 25_000_000
    let session: TrackerSession
    @State private var showingPicker = false
    @State private var data: Data?
    @State private var preview: TrackerImportPreview?
    @State private var strategy: ImportConflictStrategy = .keepExisting
    @State private var error: String?
    @State private var confirmImport = false

    var body: some View {
        Form {
            Section {
                Text("Choose a Cecy JSON export. Cecy validates the whole file and shows additions, duplicates, and conflicts before changing records.")
                Button { showingPicker = true } label: { Label("Choose Cecy JSON export", systemImage: "doc.badge.plus") }
                    .accessibilityIdentifier("chooseImport")
            } header: { Text("Import and recovery") }
            footer: { Text("Import runs in one local transaction. If validation or saving fails, existing records remain unchanged.") }

            if data != nil {
                Section("Conflict choice") {
                    Picker("When records conflict", selection: $strategy) {
                        ForEach(ImportConflictStrategy.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .onChange(of: strategy) { _, _ in preparePreview() }
                    Text("Duplicates are never added twice. Conflicts are records for the same date or identity with different content.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let preview {
                Section("Preview") {
                    LabeledContent("Export format", value: "v\(preview.formatVersion)")
                    LabeledContent("New records", value: "\(preview.added)")
                    LabeledContent("Duplicates skipped", value: "\(preview.duplicates)")
                    LabeledContent("Conflicts reviewed", value: "\(preview.conflicts)")
                    Button("Import reviewed records") { confirmImport = true }
                        .disabled(preview.added == 0 && preview.conflicts == 0)
                        .accessibilityIdentifier("commitImport")
                }
            }
            if let error { Section { InlineError(message: error) } }
            Section("Recovery boundary") {
                Text("Cecy remains local-only. This restores a user-selected export; it does not enable cloud sync or link health records to Apple sign-in.")
                Text("Exports are not encrypted. Store them only in a location you trust. Encrypted automatic backup remains unavailable until key recovery and threat modeling are complete.")
            }
        }
        .navigationTitle("Import records")
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { throw TrackingError.invalidData }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile != false,
                      values.fileSize.map({ $0 <= Self.maximumImportBytes }) ?? true else {
                    throw TrackingError.invalidData
                }
                data = try Data(contentsOf: url, options: [.mappedIfSafe])
                guard data?.count ?? 0 <= Self.maximumImportBytes else { throw TrackingError.invalidData }
                strategy = .keepExisting
                preparePreview()
            } catch {
                data = nil; preview = nil
                self.error = "This file couldn’t be read as a supported Cecy export. No records were changed."
            }
        }
        .confirmationDialog("Import these reviewed records?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Import records") {
                guard let preview else { return }
                error = session.importRecords(preview.snapshot)
                if error == nil { data = nil; self.preview = nil }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The complete import is committed together or rolled back. Existing records selected by your conflict choice are preserved.") }
    }

    private func preparePreview() {
        guard let data, let today = session.today else { return }
        do {
            preview = try TrackerImport.preview(data: data, existing: session.snapshot, today: today, strategy: strategy)
            error = nil
        } catch {
            preview = nil
            self.error = "The export contains unsupported or conflicting records. No records were changed."
        }
    }
}
