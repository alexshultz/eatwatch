import Foundation

/// The name shown to people.
///
/// Change `APP_DISPLAY_NAME` in `Supporting/AppName.xcconfig` and rebuild.
/// The home screen name, the menu name, the Health and Face ID prompts, and
/// every sentence in the app read that value. Bundle identifiers, the iCloud
/// container, and the store file names stay as they are.
public enum AppName {
    /// Used when this process has no display name, such as the package tests.
    public static let fallback = "EatWatch"

    public static var display: String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String else {
            return fallback
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return fallback }
        return trimmed
    }

    public static var importSavedLine: String {
        "\(display) saves imported data to the \(display) iCloud log."
    }

    public static var importGuidelineLine: String {
        "Apple’s guidelines prohibit saving Apple Health data in the \(display) iCloud log."
    }

    public static var importDoNotIncludeLine: String {
        "Do not include data that originated in Apple Health in your import."
    }

    public static var healthReadsWeight: String {
        "\(display) reads your weight from Health for the trend. Those readings are not saved in the \(display) log."
    }

    public static var healthCanSaveWeight: String {
        "\(display) reads your weight from Health for the trend. A weight you enter can be saved to Health. Health readings are not copied into the \(display) log."
    }

    public static var healthUnavailable: String {
        "Health is not available on this device. Weights you enter stay in \(display)."
    }

    public static var healthUnsigned: String {
        "Health access is on iPhone, iPad, and Apple Watch. This copy of \(display) is not signed for Health, so readings stay in the Health app and weights you enter stay in \(display)."
    }

    public static var healthRequestFailed: String {
        "Health access could not be requested. Weights you enter stay in \(display)."
    }
}

/// The exercise ladder in The Hacker's Diet Online. A blank rung means no exercise that day.
public enum ExerciseRung {
    public static let range = 1...48

    public static func accepted(_ value: Int?) -> Int? {
        guard let value, range.contains(value) else { return nil }
        return value
    }
}
