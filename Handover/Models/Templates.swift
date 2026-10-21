import Foundation

enum RoomKind: String, CaseIterable, Identifiable, Codable {
    case entrance, hallway, livingRoom, diningRoom, kitchen, bedroom, bathroom, ensuite, wc, utility, study, landing, stairs, garage, garden, exterior, balcony, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .entrance: return "Entrance"
        case .hallway: return "Hallway"
        case .livingRoom: return "Living room"
        case .diningRoom: return "Dining room"
        case .kitchen: return "Kitchen"
        case .bedroom: return "Bedroom"
        case .bathroom: return "Bathroom"
        case .ensuite: return "En suite"
        case .wc: return "WC"
        case .utility: return "Utility room"
        case .study: return "Study"
        case .landing: return "Landing"
        case .stairs: return "Stairs"
        case .garage: return "Garage"
        case .garden: return "Garden"
        case .exterior: return "Exterior"
        case .balcony: return "Balcony"
        case .other: return "Other room"
        }
    }

    var symbol: String {
        switch self {
        case .entrance: return "door.left.hand.closed"
        case .hallway, .landing: return "rectangle.portrait.split.2x1"
        case .livingRoom: return "sofa.fill"
        case .diningRoom: return "fork.knife"
        case .kitchen: return "refrigerator.fill"
        case .bedroom: return "bed.double.fill"
        case .bathroom, .ensuite: return "bathtub.fill"
        case .wc: return "toilet.fill"
        case .utility: return "washer.fill"
        case .study: return "desktopcomputer"
        case .stairs: return "stairs"
        case .garage: return "car.fill"
        case .garden: return "leaf.fill"
        case .exterior: return "house.fill"
        case .balcony: return "sun.max.fill"
        case .other: return "square.dashed"
        }
    }

    /// The fixtures an inventory clerk would normally list for this room.
    var defaultItems: [String] {
        let shell = ["Door & frame", "Ceiling", "Walls", "Skirting boards", "Flooring", "Windows & sills", "Lighting & switches", "Sockets"]
        switch self {
        case .entrance, .hallway, .landing:
            return shell + ["Radiator / heating", "Smoke alarm"]
        case .stairs:
            return ["Stair treads & carpet", "Banister & handrail", "Walls", "Ceiling", "Lighting & switches"]
        case .livingRoom, .diningRoom, .study:
            return shell + ["Curtains / blinds", "Radiator / heating", "Fireplace"]
        case .kitchen:
            return shell + ["Worktops", "Cupboards & drawers", "Sink & taps", "Oven & hob", "Extractor hood", "Fridge / freezer", "Dishwasher", "Washing machine", "Tiling & splashback"]
        case .bedroom:
            return shell + ["Curtains / blinds", "Radiator / heating", "Wardrobe"]
        case .bathroom, .ensuite:
            return ["Door & frame", "Ceiling", "Walls & tiling", "Flooring", "Window", "Lighting & extractor", "Bath / shower", "Shower screen / curtain", "Basin & taps", "Toilet", "Mirror & cabinet", "Towel rail"]
        case .wc:
            return ["Door & frame", "Ceiling", "Walls", "Flooring", "Toilet", "Basin & taps", "Lighting"]
        case .utility:
            return shell + ["Worktop", "Sink & taps", "Boiler", "Washing machine / dryer"]
        case .garage:
            return ["Garage door", "Walls", "Floor", "Ceiling", "Lighting & power"]
        case .garden:
            return ["Lawn", "Beds & planting", "Patio / decking", "Fencing & gates", "Shed", "Bins"]
        case .exterior:
            return ["Front door", "Brickwork & render", "Gutters & downpipes", "Windows", "Driveway / path", "Bins"]
        case .balcony:
            return ["Floor", "Balustrade", "Door", "Lighting"]
        case .other:
            return shell
        }
    }

    /// Builds the standard room list for a new property.
    static func defaultRooms(for property: Property) -> [(String, RoomKind)] {
        var rooms: [(String, RoomKind)] = []
        let isHouse = [PropertyType.house, .townhouse, .maisonette].contains(property.type)
        if property.type == .room {
            return [("Bedroom", .bedroom), ("Shared kitchen", .kitchen), ("Shared bathroom", .bathroom)]
        }
        rooms.append(("Entrance & hallway", .hallway))
        if property.type == .studio {
            rooms.append(("Living & sleeping area", .livingRoom))
            rooms.append(("Kitchen area", .kitchen))
            rooms.append(("Bathroom", .bathroom))
            return rooms
        }
        rooms.append(("Living room", .livingRoom))
        rooms.append(("Kitchen", .kitchen))
        if isHouse { rooms.append(("Stairs & landing", .stairs)) }
        let beds = max(property.bedrooms, 1)
        for index in 1...beds {
            rooms.append((beds == 1 ? "Bedroom" : "Bedroom \(index)", .bedroom))
        }
        let baths = max(property.bathrooms, 1)
        for index in 1...baths {
            rooms.append((baths == 1 ? "Bathroom" : "Bathroom \(index)", .bathroom))
        }
        if isHouse || property.type == .bungalow {
            rooms.append(("Garden", .garden))
            rooms.append(("Exterior", .exterior))
        }
        return rooms
    }
}

enum ComplianceType: String, CaseIterable, Identifiable, Codable {
    case gasSafety, eicr, epc, smokeAlarms, coAlarms, legionella, depositProtection, rightToRent, hmoLicence, landlordInsurance, interimInspection, smokeAlarmService, poolSafety, healthyHomes, leadPaint, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gasSafety: return "Gas safety certificate"
        case .eicr: return "Electrical safety (EICR)"
        case .epc: return "Energy performance (EPC)"
        case .smokeAlarms: return "Smoke alarm test"
        case .coAlarms: return "Carbon monoxide alarm test"
        case .legionella: return "Legionella risk assessment"
        case .depositProtection: return "Deposit protection deadline"
        case .rightToRent: return "Right to rent check"
        case .hmoLicence: return "HMO / property licence"
        case .landlordInsurance: return "Landlord insurance renewal"
        case .interimInspection: return "Interim inspection"
        case .smokeAlarmService: return "Smoke alarm compliance service"
        case .poolSafety: return "Pool safety certificate"
        case .healthyHomes: return "Healthy Homes compliance"
        case .leadPaint: return "Lead paint disclosure"
        case .custom: return "Custom reminder"
        }
    }

    var symbol: String {
        switch self {
        case .gasSafety: return "flame.fill"
        case .eicr: return "bolt.fill"
        case .epc: return "leaf.fill"
        case .smokeAlarms, .smokeAlarmService: return "smoke.fill"
        case .coAlarms: return "sensor.fill"
        case .legionella: return "drop.fill"
        case .depositProtection: return "lock.shield.fill"
        case .rightToRent: return "person.text.rectangle.fill"
        case .hmoLicence: return "doc.text.fill"
        case .landlordInsurance: return "umbrella.fill"
        case .interimInspection: return "clipboard.fill"
        case .poolSafety: return "figure.pool.swim"
        case .healthyHomes: return "heater.vertical.fill"
        case .leadPaint: return "paintbrush.fill"
        case .custom: return "bell.fill"
        }
    }

    /// Typical validity in months, used to suggest an expiry date.
    var typicalValidityMonths: Int? {
        switch self {
        case .gasSafety: return 12
        case .eicr: return 60
        case .epc: return 120
        case .smokeAlarms, .coAlarms: return 12
        case .legionella: return 24
        case .landlordInsurance: return 12
        case .interimInspection: return 6
        case .smokeAlarmService: return 12
        case .poolSafety: return 36
        case .hmoLicence: return 60
        default: return nil
        }
    }

    var guidance: String {
        switch self {
        case .gasSafety: return "A Gas Safe registered engineer must check gas appliances every 12 months. Give the tenant a copy within 28 days."
        case .eicr: return "Electrical installations must be inspected at least every five years by a qualified electrician."
        case .epc: return "An EPC is valid for 10 years. Rental homes generally need a rating of E or above."
        case .smokeAlarms: return "Test alarms at the start of each tenancy and record it in your check-in report."
        case .coAlarms: return "Required in rooms with a fixed combustion appliance (excluding gas cookers)."
        case .legionella: return "Assess the risk of Legionella in the water system and keep a written record."
        case .depositProtection: return "Protect the deposit and give the tenant the prescribed information within 30 days."
        case .rightToRent: return "Check that adult occupiers have the right to rent before the tenancy starts."
        case .hmoLicence: return "Licensed properties must renew before the licence expires."
        case .landlordInsurance: return "Keep buildings and landlord liability cover in force."
        case .interimInspection: return "Routine visits every 3 to 6 months catch problems early and support any later claim."
        case .smokeAlarmService: return "Annual smoke alarm servicing is required in some states."
        case .poolSafety: return "Pools and spas need a current safety certificate before leasing."
        case .healthyHomes: return "Heating, insulation, ventilation, moisture and draught standards must be met."
        case .leadPaint: return "Homes built before 1978 require a lead-based paint disclosure."
        case .custom: return "Any date you want to be reminded about."
        }
    }

    static func defaults(for region: Region) -> [ComplianceType] {
        switch region {
        case .unitedKingdom: return [.gasSafety, .eicr, .epc, .smokeAlarms, .coAlarms, .depositProtection, .rightToRent, .legionella, .landlordInsurance, .interimInspection]
        case .ireland: return [.smokeAlarms, .coAlarms, .epc, .landlordInsurance, .interimInspection]
        case .australia: return [.smokeAlarmService, .poolSafety, .landlordInsurance, .interimInspection]
        case .newZealand: return [.healthyHomes, .smokeAlarms, .landlordInsurance, .interimInspection]
        case .unitedStates: return [.smokeAlarms, .coAlarms, .leadPaint, .landlordInsurance, .interimInspection]
        case .canada: return [.smokeAlarms, .coAlarms, .landlordInsurance, .interimInspection]
        }
    }
}
