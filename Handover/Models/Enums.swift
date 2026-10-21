import SwiftUI

enum InspectionKind: String, CaseIterable, Identifiable, Codable {
    case checkIn, interim, checkOut
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .checkIn: return "key.horizontal.fill"
        case .interim: return "clipboard.fill"
        case .checkOut: return "door.left.hand.open"
        }
    }
}

enum InspectionStatus: String, Codable {
    case draft, signed

    var label: String { self == .draft ? "Draft" : "Signed" }
}

/// The standard five-point condition scale used by inventory clerks.
enum Condition: String, CaseIterable, Identifiable, Codable {
    case excellent, good, fair, poor, damaged, notApplicable
    var id: String { rawValue }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .damaged: return "Damaged"
        case .notApplicable: return "N/A"
        }
    }

    var definition: String {
        switch self {
        case .excellent: return "New or as new. No visible marks, wear or defects."
        case .good: return "Clean and sound with only minimal signs of use."
        case .fair: return "Normal signs of use: light marks, scuffs or wear."
        case .poor: return "Heavy wear, staining or marks beyond everyday use."
        case .damaged: return "Broken, torn, burnt, chipped or not working."
        case .notApplicable: return "Not present or not inspected."
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(red: 0.16, green: 0.55, blue: 0.40)
        case .good: return Color(red: 0.30, green: 0.62, blue: 0.36)
        case .fair: return Color(red: 0.80, green: 0.60, blue: 0.16)
        case .poor: return Color(red: 0.86, green: 0.42, blue: 0.16)
        case .damaged: return Color(red: 0.78, green: 0.20, blue: 0.20)
        case .notApplicable: return .secondary
        }
    }

    /// Lower is better. Used to spot deterioration between reports.
    var rank: Int {
        switch self {
        case .excellent: return 0
        case .good: return 1
        case .fair: return 2
        case .poor: return 3
        case .damaged: return 4
        case .notApplicable: return -1
        }
    }

    static var rated: [Condition] { [.excellent, .good, .fair, .poor, .damaged] }
}

enum Cleanliness: String, CaseIterable, Identifiable, Codable {
    case professional, clean, needsAttention, dirty, notApplicable
    var id: String { rawValue }

    var label: String {
        switch self {
        case .professional: return "Professionally clean"
        case .clean: return "Clean"
        case .needsAttention: return "Needs attention"
        case .dirty: return "Dirty"
        case .notApplicable: return "N/A"
        }
    }

    var shortLabel: String {
        switch self {
        case .professional: return "Pro clean"
        case .clean: return "Clean"
        case .needsAttention: return "Attention"
        case .dirty: return "Dirty"
        case .notApplicable: return "N/A"
        }
    }

    var rank: Int {
        switch self {
        case .professional: return 0
        case .clean: return 1
        case .needsAttention: return 2
        case .dirty: return 3
        case .notApplicable: return -1
        }
    }
}

/// How an item changed between check-in and check-out.
enum ChangeKind: String, CaseIterable, Identifiable, Codable {
    case unassessed, noChange, fairWear, cleaning, damage, missing
    var id: String { rawValue }

    var label: String {
        switch self {
        case .unassessed: return "Not compared"
        case .noChange: return "No change"
        case .fairWear: return "Fair wear and tear"
        case .cleaning: return "Cleaning required"
        case .damage: return "Damage"
        case .missing: return "Missing"
        }
    }

    var symbol: String {
        switch self {
        case .unassessed: return "circle.dashed"
        case .noChange: return "checkmark.circle.fill"
        case .fairWear: return "clock.arrow.circlepath"
        case .cleaning: return "sparkles"
        case .damage: return "exclamationmark.triangle.fill"
        case .missing: return "questionmark.square.dashed"
        }
    }

    var color: Color {
        switch self {
        case .unassessed: return .secondary
        case .noChange: return Color(red: 0.16, green: 0.55, blue: 0.40)
        case .fairWear: return Color(red: 0.36, green: 0.50, blue: 0.70)
        case .cleaning: return Color(red: 0.80, green: 0.60, blue: 0.16)
        case .damage: return Color(red: 0.78, green: 0.20, blue: 0.20)
        case .missing: return Color(red: 0.55, green: 0.30, blue: 0.70)
        }
    }

    /// Whether this kind of change can justify a deduction.
    var isChargeable: Bool { self == .cleaning || self == .damage || self == .missing }
}

enum PropertyType: String, CaseIterable, Identifiable, Codable {
    case flat, house, studio, maisonette, townhouse, bungalow, room
    var id: String { rawValue }

    var label: String {
        switch self {
        case .flat: return "Flat / apartment"
        case .house: return "House"
        case .studio: return "Studio"
        case .maisonette: return "Maisonette"
        case .townhouse: return "Townhouse"
        case .bungalow: return "Bungalow"
        case .room: return "Room in shared home"
        }
    }

    var symbol: String {
        switch self {
        case .flat, .maisonette: return "building.2.fill"
        case .house, .townhouse, .bungalow: return "house.fill"
        case .studio: return "square.split.bottomrightquarter.fill"
        case .room: return "bed.double.fill"
        }
    }
}

enum Furnishing: String, CaseIterable, Identifiable, Codable {
    case unfurnished, partFurnished, furnished
    var id: String { rawValue }

    var label: String {
        switch self {
        case .unfurnished: return "Unfurnished"
        case .partFurnished: return "Part furnished"
        case .furnished: return "Furnished"
        }
    }
}

enum MeterType: String, CaseIterable, Identifiable, Codable {
    case electricity, gas, water, oil, heat
    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .electricity: return "bolt.fill"
        case .gas: return "flame.fill"
        case .water: return "drop.fill"
        case .oil: return "fuelpump.fill"
        case .heat: return "thermometer.medium"
        }
    }
}

enum SignatureRole: String, CaseIterable, Identifiable, Codable {
    case landlord, tenant, agent, witness
    var id: String { rawValue }

    var label: String {
        switch self {
        case .landlord: return "Landlord"
        case .tenant: return "Tenant"
        case .agent: return "Agent / inspector"
        case .witness: return "Witness"
        }
    }
}
