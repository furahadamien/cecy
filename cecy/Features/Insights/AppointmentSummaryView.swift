import SwiftUI

struct RecordingCoverageCard: View {
    let session: TrackerSession
    let today: LocalDay
    @State private var days = 30

    var body: some View {
        TrackerCard {
            Text("Daily recording").font(.headline).accessibilityAddTraits(.isHeader)
            Picker("Date range", selection: $days) {
                Text("30 days").tag(30)
                Text("90 days").tag(90)
            }.pickerStyle(.segmented)
            if let start = try? today.adding(days: 1 - days),
               let coverage = try? RecordingCoverage(snapshot: session.snapshot, start: start, end: today) {
                Text(DayText.range(start, today)).font(.caption).foregroundStyle(.secondary)
                Text("Days logged: \(coverage.loggedDays) of \(coverage.totalDays)").font(.headline)
                    .accessibilityIdentifier("recordingCoverage")
                ForEach(DailyBleedingState.allCases, id: \.self) { state in
                    LabeledContent(state.title, value: "\(coverage.count(state))")
                }
                LabeledContent("Not logged", value: "\(coverage.unloggedDays)")
                Text("Not logged doesn’t mean no bleeding. Period ranges don’t fill in daily answers.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            NavigationLink {
                AppointmentSummaryView(session: session, today: today)
            } label: {
                Label("Appointment summary", systemImage: "doc.text").frame(minHeight: 44)
            }
            .accessibilityIdentifier("appointmentSummary")
        }
    }
}

struct AppointmentSummaryView: View {
    let session: TrackerSession
    let today: LocalDay
    @State private var start: LocalDay
    @State private var end: LocalDay
    @State private var options = AppointmentSummaryOptions()
    @State private var preview: SummaryPreview?
    @State private var error: String?

    private struct SummaryPreview: Identifiable {
        let id = UUID()
        let text: String
    }

    init(session: TrackerSession, today: LocalDay) {
        self.session = session
        self.today = today
        _start = State(initialValue: (try? today.adding(days: -89)) ?? today)
        _end = State(initialValue: today)
    }

    var body: some View {
        Form {
            Section("Dates") {
                DatePicker("From", selection: binding($start), in: ...end.formattingDate, displayedComponents: .date)
                DatePicker("Through", selection: binding($end), in: start.formattingDate...today.formattingDate, displayedComponents: .date)
            }
            Section("Include") {
                Toggle("Recorded periods", isOn: $options.periods).accessibilityIdentifier("summaryPeriods")
                Toggle("Daily answers", isOn: $options.dailyAnswers).accessibilityIdentifier("summaryDaily")
                Toggle("Symptoms and wellness", isOn: $options.symptoms).accessibilityIdentifier("summarySymptoms")
                Toggle("Current cycle context", isOn: $options.context).accessibilityIdentifier("summaryContext")
                if options.periods || options.symptoms {
                    Toggle("Private notes", isOn: $options.notes).accessibilityIdentifier("summaryNotes")
                }
            }
            Section {
                Button("Preview summary") {
                    do {
                        preview = SummaryPreview(text: try AppointmentSummary.text(snapshot: session.snapshot,
                            start: start, end: end, options: options))
                        error = nil
                    } catch { self.error = "The summary couldn’t be prepared. Try again." }
                }
                .disabled(!options.hasSection || !session.privacy.canAccess)
                .accessibilityIdentifier("previewSummary")
            } footer: {
                Text("Created on this device. Profile identity and sexual activity are excluded. Selected notes may contain personal details.")
            }
            if let error { Section { InlineError(message: error) } }
        }
        .trackerFormStyle()
        .environment(\.calendar, LocalDay.calendar)
        .environment(\.timeZone, LocalDay.calendar.timeZone)
        .navigationTitle("Appointment summary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $preview) { preview in
            AppointmentSummaryPreview(privacy: session.privacy, text: preview.text)
        }
    }

    private func binding(_ day: Binding<LocalDay>) -> Binding<Date> {
        Binding(get: { day.wrappedValue.formattingDate }, set: {
            if let value = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) { day.wrappedValue = value }
        })
    }
}

private struct AppointmentSummaryPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var privacy: TrackerPrivacy
    let text: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Not encrypted. Shared copies leave Cecy’s control.", systemImage: "exclamationmark.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let message = privacy.message { InlineError(message: message) }
                    Text(text).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("summaryPreviewText")
                }.padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button { privacy.exportSummary(text) } label: {
                    Label("Share summary", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(TrackerPrimaryButtonStyle())
                .accessibilityIdentifier("shareSummary")
                .padding()
                .background(.background)
            }
            .sheet(item: $privacy.preparedExport, onDismiss: { privacy.cleanupExport() }) { export in
                ExportShareSheet(url: export.url) { privacy.cleanupExport() }
            }
            .onDisappear { privacy.cleanupExport() }
        }
    }
}
