import Charts
import SwiftUI

struct P2DepthView: View {
    let session: TrackerSession

    private var activeStages: [LifeStageEpisode] {
        session.today.map { session.snapshot.p2.activeLifeStages(on: $0) } ?? []
    }

    var body: some View {
        SettingsForm(title: "Life stages and deeper records") {
            Section {
                NavigationLink { LifeStageTrackingView(session: session) } label: {
                    SettingsRow(title: "Cycle change and life stages", systemImage: "person.line.dotted.person",
                                detail: activeStages.isEmpty ? "None active" : activeStages.map(\.kind.title).joined(separator: ", "))
                }
                .accessibilityIdentifier("p2LifeStages")
                NavigationLink { PostpartumBleedingView(session: session) } label: {
                    SettingsRow(title: "Postpartum bleeding", systemImage: "drop.triangle",
                                detail: "\(session.snapshot.p2.postpartumBleeding.count) records")
                }
                NavigationLink { BiomarkerTrackingView(session: session) } label: {
                    SettingsRow(title: "Biomarkers", systemImage: "waveform.path.ecg.rectangle",
                                detail: "\(session.snapshot.p2.biomarkers.count) records")
                }
                .accessibilityIdentifier("p2Biomarkers")
            } header: { Text("Your records") }
            footer: {
                Text("These are records, not diagnoses. Postpartum bleeding stays separate from periods, and biomarkers do not change forecasts or confirm ovulation or pregnancy.")
            }
            Section {
                NavigationLink { EducationLibraryView() } label: {
                    SettingsRow(title: "Learning library", systemImage: "books.vertical",
                                detail: "\(EducationCatalog.articles.count) articles")
                }
                .accessibilityIdentifier("p2Learning")
                NavigationLink { AppleIntegrationBoundaryView() } label: {
                    SettingsRow(title: "Apple integrations", systemImage: "apple.logo", detail: "Shortcuts available")
                }
            } header: { Text("Learn and connect") }
            footer: { Text("Integrations that could save health data without your review stay off until permissions, signing, privacy, and device testing are complete.") }
        }
    }
}

// MARK: - Shared date helpers

private enum P2Dates {
    static func binding(_ value: Binding<LocalDay>) -> Binding<Date> {
        Binding(get: { value.wrappedValue.formattingDate }, set: {
            if let day = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) { value.wrappedValue = day }
        })
    }
    static var now: Date { Date() }
    static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

// MARK: - Life stages

private struct LifeStageTrackingView: View {
    let session: TrackerSession
    @State private var editing: LifeStageEpisode?
    @State private var adding = false

    var body: some View {
        List {
            if session.snapshot.p2.lifeStages.isEmpty {
                Section {
                    Text("No life-stage records yet.").foregroundStyle(.secondary)
                    Text("Add a stage to tailor your daily check-in, see coverage-aware summaries, and keep postpartum or feeding gaps out of cycle averages.")
                        .font(.footnote)
                }
            }
            ForEach(session.snapshot.p2.lifeStages.reversed()) { episode in
                Section {
                    LifeStageSummaryCard(session: session, episode: episode)
                    Button("Edit") { editing = episode }.accessibilityIdentifier("editLifeStage")
                }
            }
            Section {
                Text("Cecy summarizes only what you record. A calendar date cannot diagnose perimenopause, measure hormones, or predict when cycles return.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Life stages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add") { adding = true }.accessibilityIdentifier("addLifeStage")
            }
        }
        .sheet(isPresented: $adding) { LifeStageEditor(session: session, episode: nil) }
        .sheet(item: $editing) { LifeStageEditor(session: session, episode: $0) }
    }
}

private struct LifeStageSummaryCard: View {
    let session: TrackerSession
    let episode: LifeStageEpisode

    var body: some View {
        let summary = LifeStageSummary.make(episode: episode, snapshot: session.snapshot,
                                            through: session.today ?? episode.end ?? episode.start)
        VStack(alignment: .leading, spacing: 8) {
            Label(episode.kind.title, systemImage: episode.kind.symbol).font(.headline)
            Text(DayText.full(episode.start) + " – " + (episode.end.map(DayText.full) ?? String(localized: "ongoing")))
                .font(.subheadline)
            if let feeding = episode.feedingContext, feeding != .notRecorded { Text(feeding.title).font(.subheadline) }
            ForEach(summary.observations(format: DayText.full), id: \.self) { Text($0).font(.footnote) }
            if !summary.relevantSymptoms.isEmpty {
                Text("Relevant symptoms recorded").font(.subheadline.weight(.semibold))
                ForEach(summary.relevantSymptoms, id: \.kind) { item in
                    LabeledContent(item.kind.title, value: "\(item.count) days").font(.footnote)
                }
            }
            DisclosureGroup("Related reading") {
                ForEach(EducationCatalog.articles(for: episode.kind)) { article in
                    NavigationLink(article.title) { EducationArticleView(article: article) }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private struct LifeStageEditor: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let original: LifeStageEpisode?
    @State private var value: LifeStageEpisode
    @State private var hasEnd: Bool
    @State private var notes: String
    @State private var error: String?
    @State private var confirmDelete = false

    init(session: TrackerSession, episode: LifeStageEpisode?) {
        self.session = session
        original = episode
        let day = session.today ?? (try! LocalDay(key: 20010101))
        let initial = episode ?? LifeStageEpisode(kind: .cycleChange, start: day)
        _value = State(initialValue: initial)
        _hasEnd = State(initialValue: initial.end != nil)
        _notes = State(initialValue: initial.notes ?? "")
    }

    private var excludes: Binding<Bool> {
        Binding(get: { value.excludesFromForecast }, set: { value.forecastExclusion = $0 })
    }
    private var feeding: Binding<FeedingContext> {
        Binding(get: { value.feedingContext ?? .notRecorded }, set: { value.feedingContext = $0 })
    }
    private var end: Binding<LocalDay> {
        Binding(get: { value.end ?? value.start }, set: { value.end = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Life stage", selection: $value.kind) {
                        ForEach(LifeStageKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    DatePicker(value.kind == .postpartum ? "Birth or pregnancy-end date" : "Started",
                               selection: P2Dates.binding($value.start), in: ...P2Dates.now, displayedComponents: .date)
                    Toggle("Has an end date", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Ended", selection: P2Dates.binding(end),
                                   in: value.start.formattingDate...P2Dates.now, displayedComponents: .date)
                    }
                    if value.kind == .postpartum {
                        Picker("Feeding context", selection: feeding) {
                            ForEach(FeedingContext.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    TextField("Private note (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                } footer: {
                    Text(value.kind == .postpartum
                         ? "This includes any pregnancy ending, including loss. Record only what feels helpful. Postpartum bleeding is kept separate and never counted as a period."
                         : "This tailors check-ins and summaries. It does not diagnose a stage or estimate hormones.")
                }
                Section {
                    Toggle("Exclude overlapping intervals from forecasts", isOn: excludes)
                        .accessibilityIdentifier("lifeStageExcludesForecast")
                    Text("Your period records stay unchanged. Excluded intervals stay visible in forecast details, and you can include them again at any time.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Forecast use") }
                if let error { Section { InlineError(message: error) } }
                if original != nil {
                    Section { Button("Delete life-stage record", role: .destructive) { confirmDelete = true } }
                }
            }
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle(original == nil ? "Add life stage" : "Edit life stage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("saveLifeStage") }
            }
            .confirmationDialog("Delete this life-stage record?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text(original?.kind == .postpartum
                     ? "Postpartum bleeding records within these dates will also be deleted. Period records are not affected."
                     : "Period and symptom records are not affected.")
            }
            .onChange(of: hasEnd) { _, enabled in if !enabled { value.end = nil } }
            .onChange(of: value.kind) { _, kind in if kind != .postpartum { value.feedingContext = nil } }
        }
    }

    private func save() {
        var episode = value
        episode.notes = P2Dates.trimmed(notes)
        if hasEnd && episode.end == nil { episode.end = episode.start }
        if episode.kind == .postpartum && episode.feedingContext == nil { episode.feedingContext = .notRecorded }
        var data = session.snapshot.p2
        if let original {
            episode.updatedAt = max(Date(), original.createdAt)
            data.lifeStages.removeAll { $0.id == original.id }
        }
        data.lifeStages.append(episode)
        let orphaned = data.postpartumBleeding.filter { entry in
            !data.lifeStages.contains { $0.kind == .postpartum && $0.contains(entry.day) }
        }
        guard orphaned.isEmpty else {
            error = String(localized: "\(orphaned.count) postpartum bleeding records would fall outside a postpartum stage. Adjust the dates or delete those records first.")
            return
        }
        error = session.saveP2Data(data, confirmation: original == nil ? "Life-stage record saved." : "Life-stage record updated.")
        if error == nil { dismiss() }
    }

    private func delete() {
        guard let original else { return }
        var data = session.snapshot.p2
        data.lifeStages.removeAll { $0.id == original.id }
        data.postpartumBleeding.removeAll { entry in
            !data.lifeStages.contains { $0.kind == .postpartum && $0.contains(entry.day) }
        }
        error = session.saveP2Data(data, confirmation: "Life-stage record deleted.")
        if error == nil { dismiss() }
    }
}

// MARK: - Postpartum bleeding

private struct PostpartumBleedingView: View {
    let session: TrackerSession
    @State private var adding = false
    @State private var editing: PostpartumBleedingEntry?
    private var hasPostpartum: Bool { session.snapshot.p2.lifeStages.contains { $0.kind == .postpartum } }

    var body: some View {
        List {
            Section {
                ForEach(session.snapshot.p2.postpartumBleeding.reversed()) { entry in
                    Button { editing = entry } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.state.title).font(.headline)
                            Text(DayText.full(entry.day) + (entry.flow.map { " · \($0.title)" } ?? ""))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                if session.snapshot.p2.postpartumBleeding.isEmpty {
                    Text("No postpartum bleeding records.").foregroundStyle(.secondary)
                }
            }
            if !hasPostpartum {
                Section { Text("Add a postpartum life-stage record first so Cecy can keep these observations in the correct context.") }
            }
            Section {
                Text("These records never create a period or enter cycle averages. Seek urgent care for soaking a pad in an hour or less, large clots, fainting, fever, chest pain, trouble breathing, or other severe symptoms.")
                    .font(.footnote)
                NavigationLink("Postpartum bleeding and cycle return") {
                    if let article = EducationCatalog.article(id: "postpartum") { EducationArticleView(article: article) }
                }
            }
        }
        .navigationTitle("Postpartum bleeding")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Add") { adding = true }.disabled(!hasPostpartum) } }
        .sheet(isPresented: $adding) { PostpartumBleedingEditor(session: session, entry: nil) }
        .sheet(item: $editing) { PostpartumBleedingEditor(session: session, entry: $0) }
    }
}

private struct PostpartumBleedingEditor: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let original: PostpartumBleedingEntry?
    @State private var value: PostpartumBleedingEntry
    @State private var notes: String
    @State private var error: String?

    init(session: TrackerSession, entry: PostpartumBleedingEntry?) {
        self.session = session
        original = entry
        let day = session.today ?? (try! LocalDay(key: 20010101))
        let initial = entry ?? PostpartumBleedingEntry(day: day, state: .lochia)
        _value = State(initialValue: initial)
        _notes = State(initialValue: initial.notes ?? "")
    }

    private var flow: Binding<PeriodFlow> {
        Binding(get: { value.flow ?? .moderate }, set: { value.flow = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: P2Dates.binding($value.day), in: ...P2Dates.now, displayedComponents: .date)
                Picker("Observation", selection: $value.state) {
                    ForEach(PostpartumBleedingState.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if value.state == .bleeding {
                    Picker("Flow", selection: flow) { ForEach(PeriodFlow.allCases, id: \.self) { Text($0.title).tag($0) } }
                }
                TextField("Private note (optional)", text: $notes, axis: .vertical)
                if let error { Section { InlineError(message: error) } }
                if let original {
                    Section {
                        Button("Delete record", role: .destructive) {
                            var data = session.snapshot.p2
                            data.postpartumBleeding.removeAll { $0.id == original.id }
                            error = session.saveP2Data(data, confirmation: "Postpartum bleeding record deleted.")
                            if error == nil { dismiss() }
                        }
                    }
                }
            }
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle(original == nil ? "Postpartum record" : "Edit postpartum record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        var entry = value
        entry.notes = P2Dates.trimmed(notes)
        entry.flow = entry.state == .bleeding ? (entry.flow ?? .moderate) : nil
        var data = session.snapshot.p2
        guard data.lifeStages.contains(where: { $0.kind == .postpartum && $0.contains(entry.day) }) else {
            error = String(localized: "Choose a date within a postpartum life stage.")
            return
        }
        if let original {
            entry.updatedAt = max(Date(), original.createdAt)
            data.postpartumBleeding.removeAll { $0.id == original.id }
        }
        data.postpartumBleeding.append(entry)
        error = session.saveP2Data(data, confirmation: "Postpartum bleeding recorded separately from periods.")
        if error == nil { dismiss() }
    }
}

// MARK: - Biomarkers

private struct BiomarkerTrackingView: View {
    let session: TrackerSession
    @State private var adding = false
    @State private var editing: BiomarkerEntry?
    @State private var chartKind: BiomarkerKind = .basalBodyTemperature
    private var system: MeasurementSystem { session.snapshot.profile?.measurementSystem ?? .metric }
    private var recordedKinds: [BiomarkerKind] {
        BiomarkerKind.allCases.filter { kind in session.snapshot.p2.biomarkers.contains { $0.kind == kind } }
    }

    var body: some View {
        List {
            if let today = session.today, !recordedKinds.isEmpty {
                Section {
                    Picker("Record type", selection: $chartKind) {
                        ForEach(recordedKinds, id: \.self) { Text($0.title).tag($0) }
                    }
                    let trend = BiomarkerTrend.make(kind: chartKind, entries: session.snapshot.p2.biomarkers, through: today)
                    if !trend.points.isEmpty {
                        Chart(trend.points, id: \.day) { point in
                            LineMark(x: .value("Date", point.day.formattingDate),
                                     y: .value(chartKind.displayUnit(system) ?? "", chartKind.displayValue(point.value, system: system)))
                            PointMark(x: .value("Date", point.day.formattingDate),
                                      y: .value(chartKind.displayUnit(system) ?? "", chartKind.displayValue(point.value, system: system)))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                        .environment(\.timeZone, LocalDay.calendar.timeZone)
                        .accessibilityLabel(Text("\(chartKind.title) chart"))
                        .accessibilityValue(Text(trend.summary(system: system)))
                    }
                    Text(trend.summary(system: system)).font(.footnote)
                } header: { Text("Last 90 days") }
                footer: { Text("Gaps are days without a saved reading, not normal or abnormal values.") }
                .onAppear { if !recordedKinds.contains(chartKind), let first = recordedKinds.first { chartKind = first } }
            }
            Section {
                ForEach(session.snapshot.p2.biomarkers.reversed()) { entry in
                    Button { editing = entry } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.kind.title).font(.headline)
                            Text("\(DayText.full(entry.day)) · \(entry.valueText(system: system))")
                            Text(entry.provenance.title + (entry.sourceName.map { " · \($0)" } ?? ""))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                if session.snapshot.p2.biomarkers.isEmpty { Text("No biomarker records yet.").foregroundStyle(.secondary) }
            } header: { Text("Records") }
            Section {
                Text("Biomarkers are displayed as records only. They do not alter Cecy’s forecast or confirm ovulation, pregnancy, fertility, or safe days. A single positive test does not confirm ovulation or pregnancy.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Biomarkers")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Add") { adding = true }.accessibilityIdentifier("addBiomarker") } }
        .sheet(isPresented: $adding) { BiomarkerEditor(session: session, entry: nil, system: system) }
        .sheet(item: $editing) { BiomarkerEditor(session: session, entry: $0, system: system) }
    }
}

private struct BiomarkerEditor: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let original: BiomarkerEntry?
    let system: MeasurementSystem
    @State private var day: LocalDay
    @State private var kind: BiomarkerKind
    @State private var numeric: String
    @State private var result: BiomarkerResult
    @State private var notes: String
    @State private var error: String?

    init(session: TrackerSession, entry: BiomarkerEntry?, system: MeasurementSystem) {
        self.session = session
        original = entry
        self.system = system
        let kind = entry?.kind ?? .basalBodyTemperature
        _day = State(initialValue: entry?.day ?? session.today ?? (try! LocalDay(key: 20010101)))
        _kind = State(initialValue: kind)
        _numeric = State(initialValue: entry?.numericValue.map {
            kind.displayValue($0, system: system).formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        } ?? "")
        _result = State(initialValue: entry?.result ?? kind.allowedResults.first ?? .notSure)
        _notes = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: P2Dates.binding($day), in: ...P2Dates.now, displayedComponents: .date)
                Picker("Record type", selection: $kind) {
                    ForEach(BiomarkerKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(original?.provenance == .appleHealth)
                .onChange(of: kind) { _, new in result = new.allowedResults.first ?? .notSure; numeric = "" }
                if kind.supportsNumericValue {
                    TextField(kind.displayUnit(system).map { String(localized: "Value (\($0))") } ?? String(localized: "Value"), text: $numeric)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("biomarkerValue")
                } else {
                    Picker("Result", selection: $result) { ForEach(kind.allowedResults, id: \.self) { Text($0.title).tag($0) } }
                }
                TextField("Private note (optional)", text: $notes, axis: .vertical)
                if let error { Section { InlineError(message: error) } }
                if let original {
                    Section {
                        Button("Delete record", role: .destructive) {
                            var data = session.snapshot.p2
                            data.biomarkers.removeAll { $0.id == original.id }
                            error = session.saveP2Data(data, confirmation: "Biomarker record deleted.")
                            if error == nil { dismiss() }
                        }
                    }
                }
            }
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle(original == nil ? "Add biomarker" : "Edit biomarker")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("saveBiomarker") }
            }
        }
    }

    private func save() {
        var value: Double?
        if kind.supportsNumericValue {
            let parser = FloatingPointFormatStyle<Double>.number.locale(.current)
            let text = numeric.trimmingCharacters(in: .whitespaces)
            guard let parsed = (try? parser.parseStrategy.parse(text)) ?? Double(text.replacingOccurrences(of: ",", with: ".")) else {
                error = String(localized: "Enter a number.")
                return
            }
            value = kind.storedValue(parsed, system: system)
        }
        var entry = BiomarkerEntry(id: original?.id ?? UUID(), day: day, kind: kind, numericValue: value,
            result: kind.supportsNumericValue ? nil : result, provenance: original?.provenance ?? .manual,
            sourceName: original?.sourceName, notes: P2Dates.trimmed(notes),
            createdAt: original?.createdAt ?? Date())
        if let original { entry.updatedAt = max(Date(), original.createdAt) }
        var data = session.snapshot.p2
        data.biomarkers.removeAll { $0.id == entry.id }
        data.biomarkers.append(entry)
        do { try P2RecordValidation.validate(P2Data(biomarkers: [entry]), asOf: session.today) }
        catch {
            self.error = String(localized: "Check the value. Temperatures must be realistic body temperatures, heart rate 20–250 bpm, and sleep 0–24 hours.")
            return
        }
        error = session.saveP2Data(data, confirmation: "Biomarker record saved without changing forecasts.")
        if error == nil { dismiss() }
    }
}

// MARK: - Education

struct EducationLibraryView: View {
    @State private var query = ""

    var body: some View {
        List {
            let results = EducationCatalog.search(query)
            ForEach(results) { article in
                NavigationLink { EducationArticleView(article: article) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title).font(.headline)
                        Text(article.summary).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            if results.isEmpty { Text("No articles match your search.").foregroundStyle(.secondary) }
            Section {
                Text("General education, not personal medical advice. Articles show their review status, sources, and limits.")
                    .font(.footnote)
            }
        }
        .searchable(text: $query, prompt: Text("Search articles"))
        .navigationTitle("Learning library")
    }
}

struct EducationArticleView: View {
    let article: EducationArticle

    var body: some View {
        List {
            if !article.isClinicallyReviewed {
                Section {
                    Label("Draft awaiting qualified clinical review", systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Section {
                Text(article.summary).font(.headline)
                ForEach(article.body, id: \.self) { Text($0) }
            }
            Section("When to seek care") { Text(article.emergencyBoundary) }
            Section("Review and sources") {
                LabeledContent("Author", value: article.author)
                LabeledContent("Reviewer", value: article.reviewer)
                LabeledContent("Last updated", value: DayText.full(article.reviewedOn))
                Text(article.jurisdiction).font(.footnote)
                ForEach(article.references, id: \.self) { Text($0).font(.footnote) }
            }
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Apple integrations

private struct AppleIntegrationBoundaryView: View {
    var body: some View {
        List(AppleEcosystemCapability.allCases, id: \.self) { capability in
            VStack(alignment: .leading, spacing: 6) {
                Text(capability.title).font(.headline)
                if capability.isEnabledInThisBuild {
                    Label("Available", systemImage: "checkmark.circle").foregroundStyle(.green)
                } else {
                    Label("Not enabled in this build", systemImage: "lock.shield")
                }
                Text(capability.boundary).font(.footnote).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("Apple integrations")
    }
}
