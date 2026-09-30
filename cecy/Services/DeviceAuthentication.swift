import LocalAuthentication

@MainActor protocol DeviceAuthenticating {
    func authenticate(reason: String) async -> Bool
    func cancel()
}

@MainActor final class DeviceOwnerAuthentication: DeviceAuthenticating {
    private var context: LAContext?
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        self.context = context
        defer { if self.context === context { self.context = nil } }
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true
    }
    func cancel() { context?.invalidate(); context = nil }
}

@MainActor final class FixedDeviceAuthentication: DeviceAuthenticating {
    let succeeds: Bool
    init(succeeds: Bool = false) { self.succeeds = succeeds }
    func authenticate(reason: String) -> Bool { succeeds }
    func cancel() {}
}
