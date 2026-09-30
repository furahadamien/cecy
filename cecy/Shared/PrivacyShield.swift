import SwiftUI
import UIKit

/// A separate, non-key window covers app-owned sheets as well as the root hierarchy.
struct PrivacyShield: UIViewRepresentable {
    let isActive: Bool
    func makeUIView(context: Context) -> ShieldHost { ShieldHost() }
    func updateUIView(_ uiView: ShieldHost, context: Context) { uiView.setActive(isActive) }

    final class ShieldHost: UIView {
        private var cover: UIWindow?
        private var active = false
        func setActive(_ value: Bool) {
            active = value
            cover?.isHidden = value && UIApplication.shared.applicationState == .active
        }
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            NotificationCenter.default.addObserver(self, selector: #selector(hideContent), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(showContent), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        required init?(coder: NSCoder) { fatalError("Not used") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else {
                cover?.isHidden = true
                cover = nil
                return
            }
            guard cover?.windowScene !== scene else { return }
            cover?.isHidden = true
            let overlay = UIWindow(windowScene: scene)
            overlay.windowLevel = .alert + 1
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "Cecy · Private"
            label.font = .preferredFont(forTextStyle: .title2)
            label.adjustsFontForContentSizeCategory = true
            label.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(label)
            NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
                                         label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)])
            overlay.rootViewController = controller
            cover = overlay
            overlay.isHidden = active && UIApplication.shared.applicationState == .active
        }
        @objc private func hideContent() { cover?.isHidden = false }
        @objc private func showContent() { cover?.isHidden = active }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

struct LockedTrackerView: View {
    let privacy: TrackerPrivacy
    var body: some View {
        TrackerPage(title: "Cecy is locked", subtitle: "Your records stay private until you unlock.") {
            Label("Device-owner authentication", systemImage: "lock.fill")
            Text("Use Face ID, Touch ID or your device passcode. Cecy has no separate PIN or recovery bypass.")
            Button("Unlock Cecy") { Task { await privacy.unlock() } }
                .buttonStyle(.borderedProminent).frame(minHeight: 44)
                .disabled(privacy.isAuthenticating).accessibilityIdentifier("unlockCecy")
            if privacy.isAuthenticating { ProgressView("Authenticating…") }
            if let message = privacy.message { InlineError(message: message) }
        }
    }
}
