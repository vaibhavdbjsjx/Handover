import Foundation

/// The market a landlord lets property in. Drives terminology, currency,
/// paper size, deposit schemes and the compliance checklist.
enum Region: String, CaseIterable, Identifiable, Codable {
    case unitedKingdom = "GB"
    case ireland = "IE"
    case australia = "AU"
    case newZealand = "NZ"
    case unitedStates = "US"
    case canada = "CA"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unitedKingdom: return "United Kingdom"
        case .ireland: return "Ireland"
        case .australia: return "Australia"
        case .newZealand: return "New Zealand"
        case .unitedStates: return "United States"
        case .canada: return "Canada"
        }
    }

    var flag: String {
        switch self {
        case .unitedKingdom: return "🇬🇧"
        case .ireland: return "🇮🇪"
        case .australia: return "🇦🇺"
        case .newZealand: return "🇳🇿"
        case .unitedStates: return "🇺🇸"
        case .canada: return "🇨🇦"
        }
    }

    var currencyCode: String {
        switch self {
        case .unitedKingdom: return "GBP"
        case .ireland: return "EUR"
        case .australia: return "AUD"
        case .newZealand: return "NZD"
        case .unitedStates: return "USD"
        case .canada: return "CAD"
        }
    }

    var usesLetterPaper: Bool { self == .unitedStates || self == .canada }

    /// What the money held against damage is called locally.
    var depositTerm: String {
        switch self {
        case .australia, .newZealand: return "bond"
        case .unitedStates, .canada: return "security deposit"
        default: return "deposit"
        }
    }

    var postcodeLabel: String {
        switch self {
        case .unitedStates: return "ZIP code"
        case .canada: return "Postal code"
        case .ireland: return "Eircode"
        default: return "Postcode"
        }
    }

    var cityLabel: String {
        switch self {
        case .unitedKingdom, .ireland: return "Town or city"
        case .australia: return "Suburb"
        default: return "City"
        }
    }

    var stateLabel: String? {
        switch self {
        case .australia, .unitedStates: return "State"
        case .canada: return "Province"
        default: return nil
        }
    }

    /// Deposit or bond schemes a report may be submitted to.
    var depositSchemes: [String] {
        switch self {
        case .unitedKingdom:
            return ["Tenancy Deposit Scheme (TDS)", "Deposit Protection Service (DPS)", "mydeposits", "SafeDeposits Scotland", "Letting Protection Service Scotland", "TDS Northern Ireland"]
        case .ireland:
            return ["Residential Tenancies Board (RTB)"]
        case .australia:
            return ["NSW Fair Trading Rental Bonds Online", "Residential Tenancies Authority (QLD)", "Residential Tenancies Bond Authority (VIC)", "Consumer and Business Services (SA)", "Bond Administrator (WA)", "Rental Deposits Authority (TAS)", "ACT Revenue Office", "NT Consumer Affairs"]
        case .newZealand:
            return ["Tenancy Services (MBIE)"]
        case .unitedStates, .canada:
            return ["Held by landlord", "Held in escrow account"]
        }
    }

    func reportTitle(for kind: InspectionKind) -> String {
        switch (self, kind) {
        case (.unitedKingdom, .checkIn), (.ireland, .checkIn): return "Inventory & Check-In Report"
        case (.unitedKingdom, .checkOut), (.ireland, .checkOut): return "Check-Out Report"
        case (.australia, .checkIn), (.newZealand, .checkIn): return "Entry Condition Report"
        case (.australia, .checkOut), (.newZealand, .checkOut): return "Exit Condition Report"
        case (.unitedStates, .checkIn), (.canada, .checkIn): return "Move-In Inspection Report"
        case (.unitedStates, .checkOut), (.canada, .checkOut): return "Move-Out Inspection Report"
        case (_, .interim): return "Interim Inspection Report"
        }
    }

    func shortName(for kind: InspectionKind) -> String {
        switch (self, kind) {
        case (.unitedStates, .checkIn), (.canada, .checkIn): return "Move-in"
        case (.unitedStates, .checkOut), (.canada, .checkOut): return "Move-out"
        case (.australia, .checkIn), (.newZealand, .checkIn): return "Entry"
        case (.australia, .checkOut), (.newZealand, .checkOut): return "Exit"
        case (_, .checkIn): return "Check-in"
        case (_, .checkOut): return "Check-out"
        case (_, .interim): return "Interim"
        }
    }

    static var deviceDefault: Region {
        let code = Locale.current.region?.identifier ?? "GB"
        return Region(rawValue: code) ?? .unitedKingdom
    }
}

extension Double {
    func currency(_ region: Region) -> String {
        formatted(.currency(code: region.currencyCode))
    }
}
