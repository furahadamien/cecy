import SwiftUI

struct ObservationsView: View {
    let session: TrackerSession
    @State private var showHidden = false
    private var arranged: (visible: [CycleInsight], hidden: [CycleInsight]) {
        InsightQuality.arrange(session.insights, feedback: session.snapshot.p2.insightFeedback)
    }
    var body: some View {
        TrackerPage(title: "Observations", subtitle: "From your records, not assumptions.") {
            if let confirmation = session.confirmation {
                Label(confirmation, systemImage: "checkmark.circle")
                    .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
                Button("Dismiss confirmation") { session.confirmation = nil }.frame(minHeight: 44)
            }
            if let today = session.today { SymptomLogButton(session: session, day: today) }
            NavigationLink {
                AIFeatureView(session: session, feature: .records)
            } label: { Label("Generate insights", systemImage: "sparkles").frame(minHeight: 44) }
                .accessibilityIdentifier("generateRecordInsights")
            if let message = session.insightMessage {
                InlineError(message: message)
                    .onAppear { AccessibilityNotification.Announcement(message).post() }
            }
            if session.insights.isEmpty {
                TrackerCard {
                    Text("No repeated pattern to show yet.").font(.headline)
                    Text("Keep logging to build a clearer local record over time.")
                    Text("Timing observations need matching logs near at least three eligible period starts. Changes compare two groups of three completed records. Sparse or missing logs do not mean symptom-free days.")
                }
            }
            DisclosureGroup("How observations are selected") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timing uses up to six recent recorded starts whose two following days have elapsed. Starts fewer than six days from a neighboring start are excluded so windows do not overlap.")
                    Text("A log must match at least three starts and at least 60% of eligible starts. We compare three days before the start with the start day and two days after—not predicted phases or confirmed bleeding duration. Multiple logs near one start count once.")
                    Text("Sleep and energy timing uses only explicit Poor or Low ratings. Repeated recorded evidence requires at least five matches among six eligible starts; otherwise evidence is Limited.")
                    Text("Changes compare the previous three records with the recent three: at least 3 days in mean interval, 2 days in population standard deviation, or 1 day in mean confirmed duration. Duration needs ends for all six recent periods.")
                    Text("These are conservative display rules, not medical cutoffs, measured probabilities, or proof of cause. Missing logs never imply absence.")
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            ForEach(arranged.visible) { insight in
                InsightCard(insight: insight, session: session)
                NavigationLink {
                    AIFeatureView(session: session, feature: .insight(insight))
                } label: { Label("Explain this observation", systemImage: "sparkles").frame(minHeight: 44) }
                .accessibilityIdentifier("explainInsight_\(insight.id)")
            }
            if !arranged.hidden.isEmpty {
                DisclosureGroup(isExpanded: $showHidden) {
                    Text("Hidden because you marked them not helpful. They return automatically if new records change the evidence.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(arranged.hidden) { insight in
                        HStack {
                            Text(insight.title)
                            Spacer()
                            Button("Show again") { _ = session.clearInsightFeedback(InsightQuality.fingerprint(insight)) }
                                .buttonStyle(.bordered)
                        }
                    }
                } label: { Text("Hidden observations (\(arranged.hidden.count))") }
                .frame(minHeight: 44)
                .accessibilityIdentifier("hiddenInsights")
            }
            TrackerCard {
                Text("Recorded-day counts · All history").font(.headline)
                Text("Counts describe days logged, not how often you experienced a symptom. Sleep and energy are ratings, not adverse symptoms by themselves.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(SymptomKind.allCases, id: \.self) { kind in
                    let count = session.snapshot.symptoms.filter { $0.kind == kind }.count
                    if count > 0 { Text("\(kind.title): \(count) recorded days") }
                }
                if session.snapshot.symptoms.isEmpty { Text("No observations recorded yet.") }
            }
            Text("Recorded observations").font(.title2).accessibilityAddTraits(.isHeader)
            LazyVStack(spacing: 10) {
                ForEach(session.snapshot.symptoms.reversed()) { entry in
                    SymptomRecordView(session: session, entry: entry)
                }
            }
            Text("Calculated from your records, not medical diagnoses. Pattern policy v\(CycleInsightEngine.policyVersion).")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct InsightCard: View {
    let insight: CycleInsight
    var session: TrackerSession?
    @State private var askingWhy = false
    private var key: String { InsightQuality.fingerprint(insight) }
    private var feedback: InsightFeedback? { session?.snapshot.p2.insightFeedback.first { $0.insightID == key } }
    var body: some View {
        TrackerCard {
            Text(insight.title).font(.headline)
            Text(insight.explanation)
            Text(insight.evidence.rawValue).font(.subheadline.weight(.medium))
            Text(DayText.range(insight.rangeStart, insight.rangeEnd)).font(.footnote)
            Text("Evidence coverage: " + InsightQuality.coverage(insight)).font(.footnote).foregroundStyle(.secondary)
            Text("What would make this stronger: " + InsightQuality.strengthening(insight))
                .font(.footnote).foregroundStyle(.secondary)
            DisclosureGroup("Supporting records") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(insight.timing, id: \.start) { support in
                        Text("Start: \(DayText.full(support.start))")
                        Text(support.logDays.isEmpty ? "No matching recorded observation—not evidence of absence."
                             : "Logged: " + support.logDays.map { DayText.full($0) }.joined(separator: "; "))
                            .font(.footnote)
                    }
                    if let old = insight.previousMetric, let recent = insight.recentMetric {
                        Text("Previous three: " + insight.previousValues.map { "\($0)" }.joined(separator: ", ") + " days")
                        Text("Recent three: " + insight.recentValues.map { "\($0)" }.joined(separator: ", ") + " days")
                        Text("Previous metric: \(old.formatted(.number.precision(.fractionLength(1)))) days")
                        Text("Recent metric: \(recent.formatted(.number.precision(.fractionLength(1)))) days")
                    }
                    Text("Calculated \(DayText.full(insight.generatedDay)). Heuristic evidence labels are not measured probabilities or prediction confidence.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            if let session {
                if let feedback {
                    Label(feedback.helpful ? "Marked helpful on this device" : "Marked not helpful on this device",
                          systemImage: feedback.helpful ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.footnote)
                    if !feedback.reasons.isEmpty {
                        Text(InsightFeedbackReason.allCases.filter(feedback.reasons.contains).map(\.title).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Helpful") { _ = session.rateInsight(key, helpful: true); askingWhy = true }
                        .accessibilityIdentifier("insightHelpful_\(insight.id)")
                    Button("Not helpful") { askingWhy = true }
                        .accessibilityIdentifier("insightNotHelpful_\(insight.id)")
                }
                .buttonStyle(.bordered)
                Text("Feedback stays on this device and never changes your records.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $askingWhy) {
            if let session {
                InsightFeedbackSheet(session: session, key: key, initialHelpful: feedback?.helpful ?? false,
                                     initialReasons: feedback?.reasons ?? [])
            }
        }
    }
}

private struct InsightFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let key: String
    @State var helpful: Bool
    @State var reasons: Set<InsightFeedbackReason>
    @State private var error: String?

    init(session: TrackerSession, key: String, initialHelpful: Bool, initialReasons: Set<InsightFeedbackReason>) {
        self.session = session
        self.key = key
        _helpful = State(initialValue: initialHelpful)
        _reasons = State(initialValue: initialReasons)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("This observation was", selection: $helpful) {
                    Text("Helpful").tag(true)
                    Text("Not helpful").tag(false)
                }
                .pickerStyle(.segmented)
                Section {
                    ForEach(InsightFeedbackReason.allCases.filter { $0.isPositive == helpful }, id: \.self) { reason in
                        Toggle(reason.title, isOn: Binding(get: { reasons.contains(reason) }, set: {
                            if $0 { reasons.insert(reason) } else { reasons.remove(reason) }
                        }))
                    }
                } header: { Text("Why? (optional)") }
                footer: {
                    Text(helpful ? "Saved only on this device."
                         : "Saved only on this device. This observation will be hidden until new records change its evidence.")
                }
                if let error { Section { InlineError(message: error) } }
            }
            .navigationTitle("Observation feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        error = session.rateInsight(key, helpful: helpful,
                                                    reasons: reasons.filter { $0.isPositive == helpful })
                        if error == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveInsightFeedback")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
