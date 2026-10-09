import Foundation

/// What this device can do with the private iCloud database right now.
public enum ICloudSyncState: Sendable, Equatable {
    case checking
    case syncing
    case signedOut
    case unavailable
    case localOnly

    public var detail: String {
        switch self {
        case .checking:
            "Checking iCloud…"
        case .syncing:
            "Weigh-ins, the goal, and units sync across the devices on this iCloud account."
        case .signedOut:
            "Sign in to iCloud to sync this log. Until then it stays on this device."
        case .unavailable:
            "iCloud can’t be reached right now. Changes stay on this device and sync when it can."
        case .localOnly:
            "This copy is stored only on this device."
        }
    }
}
