import LocalAuthentication
import SwiftUI
import EatWatchCore

struct LockScreen: View {
    var onUnlock: () -> Void
    @State private var message = "Unlock to open the log."

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("\(AppName.display) is locked")
                .font(.title2.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Unlock", action: requestUnlock)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await unlock() }
    }

    private func requestUnlock() {
        Task { await unlock() }
    }

    private func unlock() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = error?.localizedDescription ?? "Set a passcode on this device to use the lock."
            return
        }
        do {
            if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your weight log") {
                onUnlock()
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
