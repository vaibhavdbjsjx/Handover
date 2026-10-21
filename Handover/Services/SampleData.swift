import Foundation
import SwiftData

/// A realistic example so new users (and App Review) can explore a finished
/// report before photographing a real property.
enum SampleData {
    private static let descriptions: [String: (String, Condition, Cleanliness)] = [
        "Door & frame": ("White painted panel door with chrome lever handle. Frame sound. Light scuffing to lower edge.", .good, .clean),
        "Ceiling": ("White emulsion, smooth finish. Central pendant fitting. No cracks or staining seen.", .good, .clean),
        "Walls": ("Magnolia emulsion throughout. Two small picture-hook holes on chimney breast wall. Minor scuffs by door.", .good, .clean),
        "Skirting boards": ("White gloss timber skirting. Light chips to paint at corners.", .fair, .clean),
        "Flooring": ("Grey fitted carpet, good pile. Light wear at threshold. No stains seen.", .good, .professional),
        "Windows & sills": ("White uPVC double-glazed casement, two openers, both operate. Seals intact. Keys present.", .good, .clean),
        "Lighting & switches": ("White plastic switch plate and ceiling pendant. All tested working.", .good, .clean),
        "Sockets": ("Three double white sockets. No visible damage.", .good, .clean),
        "Radiator / heating": ("White panel radiator with thermostatic valve. Warm when tested. Light paint chip to top edge.", .good, .clean),
        "Curtains / blinds": ("Cream roller blind, operates smoothly. No tears.", .good, .clean),
        "Fireplace": ("Decorative white surround, sealed opening. Not in use.", .good, .clean),
        "Smoke alarm": ("Ceiling-mounted mains alarm. Tested and sounding at inspection.", .good, .clean),
        "Worktops": ("Laminate oak-effect worktop. One small burn mark (approx. 2cm) to right of hob.", .fair, .clean),
        "Cupboards & drawers": ("Eight white gloss doors, four drawers. All open and close. Hinges adjusted.", .good, .clean),
        "Sink & taps": ("Stainless steel 1.5 bowl sink, chrome mixer tap. Plug and chain present. No leaks.", .good, .professional),
        "Oven & hob": ("Stainless single electric oven and four-ring ceramic hob. Professionally cleaned. Manual present.", .excellent, .professional),
        "Extractor hood": ("Stainless chimney hood. Light and fan work. Filters clean.", .good, .professional),
        "Fridge / freezer": ("Integrated fridge freezer. Working at inspection. Shelves and drawers complete.", .good, .professional),
        "Dishwasher": ("Integrated dishwasher. Not run at inspection. Interior clean.", .good, .clean),
        "Washing machine": ("Integrated washer-dryer. Door seal clean, drawer clean.", .good, .clean),
        "Tiling & splashback": ("White metro tiles, grey grout. One hairline crack to tile behind sink.", .fair, .clean),
        "Wardrobe": ("Built-in double wardrobe, sliding mirrored doors. Rail and shelf present. Runners smooth.", .good, .clean),
        "Walls & tiling": ("White ceramic tiles to full height around bath, emulsion elsewhere. Grout sound.", .good, .professional),
        "Window": ("Frosted uPVC window, opens and closes. Trickle vent present.", .good, .clean),
        "Lighting & extractor": ("Two recessed spotlights and ceiling extractor fan. Both working.", .good, .clean),
        "Bath / shower": ("White acrylic bath with thermostatic shower over. Sealant intact. Good pressure.", .good, .professional),
        "Shower screen / curtain": ("Hinged glass screen, no chips. Seal attached.", .good, .professional),
        "Basin & taps": ("White pedestal basin with chrome mixer tap. Plug present.", .good, .professional),
        "Toilet": ("White close-coupled toilet with soft-close seat. Flushes correctly.", .good, .professional),
        "Mirror & cabinet": ("White mirrored cabinet, one shelf. Mirror unmarked.", .good, .clean),
        "Towel rail": ("Chrome heated towel rail. Warm when tested.", .good, .clean)
    ]

    static func insert(into context: ModelContext) {
        let region = Preferences.region
        let property = Property(nickname: "Sample · Maple Court", addressLine1: "Flat 4, 14 Maple Court", city: region == .unitedStates ? "Austin" : "Bristol", state: region.stateLabel != nil ? (region == .australia ? "NSW" : "TX") : "", postcode: region == .unitedStates ? "78701" : "BS1 4DJ", region: region, type: .flat, furnishing: .partFurnished, bedrooms: 2, bathrooms: 1)
        property.isSample = true
        property.notes = "This is a sample property so you can explore Handover. Delete it whenever you like."
        context.insert(property)

        for type in ComplianceType.defaults(for: region) {
            let item = ComplianceItem(type: type)
            context.insert(item)
            item.property = property
            if let months = type.typicalValidityMonths {
                item.issuedAt = Calendar.current.date(byAdding: .month, value: -months + 1, to: .now)
                item.expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: .now)
            }
        }

        let checkIn = InspectionFactory.makeCheckIn(for: property, in: context)
        checkIn.date = Calendar.current.date(byAdding: .month, value: -12, to: .now) ?? .now
        checkIn.tenancyStartDate = checkIn.date
        checkIn.tenantNames = "Jordan Ellis"
        checkIn.tenantEmail = "jordan@example.com"
        checkIn.landlordName = Preferences.companyName.isEmpty ? "Sample Lettings" : Preferences.companyName
        checkIn.depositAmount = region == .unitedStates ? 1800 : 1350
        checkIn.depositScheme = region.depositSchemes.first ?? ""
        checkIn.depositReference = "SAMPLE-20481"
        checkIn.generalNotes = "Property professionally cleaned before the tenancy. All appliances tested and working."
        fill(checkIn)
        for (index, meter) in checkIn.sortedMeters.enumerated() {
            meter.reading = ["04821", "11930", "00412"][min(index, 2)]
            meter.serialNumber = ["E17A0042", "G4N11930", "W0021"][min(index, 2)]
            meter.location = ["Hall cupboard", "Kitchen, under sink", "Pavement outside"][min(index, 2)]
        }
        checkIn.status = .signed
        checkIn.signedAt = checkIn.date
        for room in checkIn.rooms { room.isMarkedComplete = true }

        let checkOut = InspectionFactory.makeFollowUp(kind: .checkOut, for: property, baseline: checkIn, in: context)
        checkOut.generalNotes = "Sample check-out. Open a room and see how changes are compared."
        for room in checkOut.sortedRooms {
            room.aiComparedAt = .now
            for item in room.items {
                item.change = .noChange
                item.changeNote = "Consistent with \(region.shortName(for: .checkIn).lowercased())."
            }
            if room.kind == .livingRoom, let carpet = room.items.first(where: { $0.name == "Flooring" }) {
                carpet.change = .damage
                carpet.condition = .poor
                carpet.itemDescription = "Grey fitted carpet. Red wine stain approx. 30cm by sofa position. General wear at threshold."
                carpet.changeNote = "New stain not present at check-in. Specialist cleaning attempted would be cheaper than replacement."
                carpet.deductionAmount = 120
            }
            if room.kind == .kitchen, let oven = room.items.first(where: { $0.name == "Oven & hob" }) {
                oven.change = .cleaning
                oven.cleanliness = .dirty
                oven.itemDescription = "Stainless oven and ceramic hob. Heavy grease build-up to oven interior and racks."
                oven.changeNote = "Was professionally cleaned at check-in. Needs a professional oven clean."
                oven.deductionAmount = 65
            }
            if room.kind == .bedroom, let walls = room.items.first(where: { $0.name == "Walls" }) {
                walls.change = .fairWear
                walls.changeNote = "Light scuffs and fading after 12 months of normal use. Not chargeable."
            }
        }
        try? context.save()
    }

    private static func fill(_ inspection: Inspection) {
        for room in inspection.rooms {
            room.summary = "\(room.name) in good overall condition and clean throughout."
            for item in room.items {
                if let entry = descriptions[item.name] {
                    item.itemDescription = entry.0
                    item.condition = entry.1
                    item.cleanliness = entry.2
                } else {
                    item.itemDescription = "Present and in good order."
                }
            }
        }
    }
}
