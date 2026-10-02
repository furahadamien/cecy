import SwiftUI
import UIKit

/// A separate, non-key window covers app-owned sheets as well as the root hierarchy.
struct PrivacyShield: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let isActive: Bool
    func makeUIView(context: Context) -> ShieldHost { ShieldHost() }
    func updateUIView(_ uiView: ShieldHost, context: Context) {
        uiView.setAppearance(colorScheme == .dark ? .dark : .light)
        uiView.setActive(isActive)
    }

    final class ShieldHost: UIView {
        private var cover: UIWindow?
        private var active = false
        private var appearance: UIUserInterfaceStyle = .unspecified
        func setAppearance(_ value: UIUserInterfaceStyle) {
            appearance = value
            cover?.overrideUserInterfaceStyle = value
        }
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
            overlay.overrideUserInterfaceStyle = appearance
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
    @Environment(\.colorScheme) private var colorScheme
    let privacy: TrackerPrivacy
    var body: some View {
        VStack(spacing: 16) {
            Button("Unlock") { Task { await privacy.unlock() } }
                .buttonStyle(TrackerPrimaryButtonStyle()).frame(minHeight: 44)
                .disabled(privacy.isAuthenticating).accessibilityIdentifier("unlockCecy")
            if privacy.isAuthenticating { ProgressView().accessibilityLabel("Unlocking") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrackerPalette(scheme: colorScheme).background.ignoresSafeArea())
    }
}
