import Foundation

/// App-wide constants. Website and support links live here so they can be
/// changed in one place before submission.
enum AppConfig {
    static let appName = "Handover"

    // Replace with your live website once it is published (see /Website).
    static let websiteURL = URL(string: "https://handoverapp.co")!
    static let privacyURL = URL(string: "https://handoverapp.co/privacy")!
    static let termsURL = URL(string: "https://handoverapp.co/terms")!
    static let supportURL = URL(string: "https://handoverapp.co/support")!
    static let supportEmail = "support@handoverapp.co"

    /// Apple's standard licensed application end user licence agreement.
    static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    static var apiBaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "HandoverAPIBaseURL") as? String,
              raw.hasPrefix("http"), !raw.contains("YOUR-SUBDOMAIN") else { return nil }
        return URL(string: raw)
    }

    static var appKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "HandoverAppKey") as? String) ?? ""
    }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    // Free tier limits
    static let freeAIRooms = 3
    static let freeProperties = 1
}

/// Keys for values kept in UserDefaults.
enum PrefKey {
    static let hasOnboarded = "hasOnboarded"
    static let region = "region"
    static let userName = "userName"
    static let companyName = "companyName"
    static let userEmail = "userEmail"
    static let userPhone = "userPhone"
    static let tagLocation = "tagLocation"
    static let aiConsent = "aiConsentGiven"
    static let aiRoomsUsed = "aiRoomsUsed"
    static let reportCredits = "reportCredits"
    static let deviceID = "deviceID"
    static let logoFilename = "logoFilename"
}

enum Preferences {
    static var region: Region {
        Region(rawValue: UserDefaults.standard.string(forKey: PrefKey.region) ?? "") ?? Region.deviceDefault
    }

    static var userName: String { UserDefaults.standard.string(forKey: PrefKey.userName) ?? "" }
    static var companyName: String { UserDefaults.standard.string(forKey: PrefKey.companyName) ?? "" }
    static var userEmail: String { UserDefaults.standard.string(forKey: PrefKey.userEmail) ?? "" }
    static var userPhone: String { UserDefaults.standard.string(forKey: PrefKey.userPhone) ?? "" }
    static var logoFilename: String? { UserDefaults.standard.string(forKey: PrefKey.logoFilename) }

    static var tagLocation: Bool {
        UserDefaults.standard.object(forKey: PrefKey.tagLocation) as? Bool ?? true
    }

    static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: PrefKey.deviceID) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: PrefKey.deviceID)
        return new
    }
}
