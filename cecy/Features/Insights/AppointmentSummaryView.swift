import SwiftUI

struct RecordingCoverageCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let today: LocalDay
    @State private var days = 30

    var body: some View {
        TrackerCard {
            InsightSectionHeader(title: "Daily recording", symbol: "chart.bar.fill", subtitle: "Your logs over time")
            Picker("Date range", selection: $days) {
                Text("30 days").tag(30)
                Text("90 days").tag(90)
            }.pickerStyle(.segmented)
            if let start = try? today.adding(days: 1 - days),
               let coverage = try? RecordingCoverage(snapshot: session.snapshot, start: start, end: today) {
                Text(DayText.range(start, today)).font(.caption).foregroundStyle(.secondary)
                RecordingCoverageOverview(coverage: coverage)
                Divider()
                ForEach(DailyBleedingState.allCases, id: \.self) { state in
                    RecordingCoverageRow(title: state.title, symbol: state.symbol, count: coverage.count(state), total: coverage.totalDays,
                                         tint: state == .bleeding || state == .spotting ? TrackerPalette(scheme: colorScheme).recorded : TrackerPalette(scheme: colorScheme).accent)
                }
                RecordingCoverageRow(title: "Not logged", symbol: "nosign", count: coverage.unloggedDays, total: coverage.totalDays, tint: .secondary)
                Text("Not logged doesn’t mean no bleeding. Period ranges don’t fill in daily answers.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            NavigationLink {
                AppointmentSummaryView(session: session, today: today)
            } label: {
                TrackerNavigationLabel(title: "Appointment summary", symbol: "doc.text",
                                       detail: "Prepare for your next appointment.")
                    .padding(12)
                    .background(TrackerPalette(scheme: colorScheme).sage.opacity(0.45), in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
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
        let document: AppointmentSummaryDocument
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
                        preview = SummaryPreview(document: try AppointmentSummary.document(snapshot: session.snapshot,
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
            AppointmentSummaryPreview(privacy: session.privacy, document: preview.document)
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
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var privacy: TrackerPrivacy
    let document: AppointmentSummaryDocument

    private var palette: TrackerPalette { TrackerPalette(scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let message = privacy.message { InlineError(message: message) }
                    TrackerCard(highlighted: true) {
                        Text(document.title)
                            .font(TrackerTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("summaryPreviewTitle")
                        Label(document.dateRange, systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(palette.sage, in: RoundedRectangle(cornerRadius: 12))
                        Text(document.notice).font(.footnote).foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    ForEach(document.sections) { section in
                        TrackerCard {
                            HStack(spacing: 12) {
                                Image(systemName: section.kind.previewSymbol)
                                    .font(.headline)
                                    .foregroundStyle(section.kind == .periods ? palette.recorded : palette.accent)
                                    .frame(width: 36, height: 36)
                                    .background(section.kind == .periods ? palette.recordedSurface : palette.sage,
                                                in: RoundedRectangle(cornerRadius: 12))
                                    .accessibilityHidden(true)
                                Text(section.kind.previewTitle).font(.headline)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            Divider().overlay(palette.accent.opacity(0.12))
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                                    Text(verbatim: line)
                                        .font(.subheadline).lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("summarySection_\(section.kind.rawValue)")
                    }
                }
                .textSelection(.enabled)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("summaryPreviewText")
                .frame(maxWidth: TrackerLayout.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(TrackerLayout.pageInset)
            }
            .background(palette.background)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Label("Not encrypted. Shared copies leave Cecy’s control.", systemImage: "exclamationmark.shield")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { privacy.exportSummary(document.text) } label: {
                        Label("Share summary", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(TrackerPrimaryButtonStyle())
                    .accessibilityIdentifier("shareSummary")
                }
                .frame(maxWidth: TrackerLayout.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(TrackerLayout.pageInset)
                .background(palette.surface)
            }
            .sheet(item: $privacy.preparedExport, onDismiss: { privacy.cleanupExport() }) { export in
                ExportShareSheet(url: export.url) { privacy.cleanupExport() }
            }
            .onDisappear { privacy.cleanupExport() }
        }
    }
}

private extension AppointmentSummaryDocument.Section.Kind {
    var previewTitle: String {
        switch self {
        case .dailyAnswers: "Daily answers"
        case .periods: "Recorded periods"
        case .symptoms: "Symptoms and wellness"
        case .context: "Current cycle context"
        }
    }

    var previewSymbol: String {
        switch self {
        case .dailyAnswers: "checkmark.circle"
        case .periods: "drop.fill"
        case .symptoms: "waveform.path.ecg"
        case .context: "person.text.rectangle"
        }
    }
}
