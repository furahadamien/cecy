import SwiftUI

struct ReminderChoiceLabel: View {
    let kind: ReminderRequest.Kind

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kind.title)
            Text(kind.scheduleDescription)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ReminderMessageFields: View {
    let daily: Bool
    let window: Bool
    @Binding var showDetails: Bool

    var body: some View {
        Toggle(isOn: $showDetails) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Show reminder details")
                Text("Mention periods and symptoms in notifications, including lock-screen previews.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("reminderDetails")
        ForEach([ReminderRequest.Kind.daily, .window].filter { $0 == .daily ? daily : window }, id: \.rawValue) { kind in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(kind.title) preview").font(.caption).foregroundStyle(.secondary)
                Text(kind.notificationTitle(showDetails: showDetails)).font(.subheadline.weight(.semibold))
                Text(kind.notificationBody(showDetails: showDetails)).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("reminderPreview_\(kind.rawValue)")
        }
    }
}