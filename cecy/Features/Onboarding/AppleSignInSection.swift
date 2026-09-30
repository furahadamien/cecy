import AuthenticationServices
import SwiftUI

struct AppleSignInSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let profileID: UUID
    let onSuccess: () -> Void
    @State private var requestToken: UUID?

    var body: some View {
        Section {
            Text("Sign in with Apple to create your Cecy account.")
            Text("Your health data stays on your device.").font(.headline)
            #if DEBUG
            if session.account.usesTestAuthorization {
                Button("Continue with Apple (test)") {
                    if session.account.authorizeForUITest(profileID: profileID, protectsExistingProfile: session.snapshot.profile != nil) { onSuccess() }
                }.frame(minHeight: 50).accessibilityIdentifier("continueWithApple")
            } else { appleButton }
            #else
            appleButton
            #endif
            if let message = session.account.message { InlineError(message: message) }
        } footer: {
            Text("Apple sign-in identifies you; it does not back up your health records or restore them on another device. An internet connection is needed to sign in.")
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [] // The preferred name comes from the local draft. No email is needed.
            requestToken = session.account.beginAuthorization()
        } onCompletion: { result in
            guard session.privacy.canAccess, let token = requestToken else { return }
            requestToken = nil
            if session.account.accept(result, token: token, profileID: profileID,
                                      protectsExistingProfile: session.snapshot.profile != nil) { onSuccess() }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .accessibilityIdentifier("continueWithApple")
        .disabled(session.account.isSigningIn || session.isSaving)
    }
}