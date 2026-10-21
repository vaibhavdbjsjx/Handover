import Foundation
import SwiftData

// MARK: - Property

@Model
final class Property {
    var id: UUID
    var nickname: String
    var addressLine1: String
    var addressLine2: String
    var city: String
    var state: String
    var postcode: String
    var regionRaw: String
    var typeRaw: String
    var furnishingRaw: String
    var bedrooms: Int
    var bathrooms: Int
    var coverPhotoFilename: String?
    var notes: String
    var createdAt: Date
    var isSample: Bool

    @Relationship(deleteRule: .cascade, inverse: \Inspection.property)
    var inspections: [Inspection] = []

    @Relationship(deleteRule: .cascade, inverse: \ComplianceItem.property)
    var complianceItems: [ComplianceItem] = []

    init(nickname: String = "", addressLine1: String = "", addressLine2: String = "", city: String = "", state: String = "", postcode: String = "", region: Region, type: PropertyType = .flat, furnishing: Furnishing = .unfurnished, bedrooms: Int = 1, bathrooms: Int = 1) {
        self.id = UUID()
        self.nickname = nickname
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.state = state
        self.postcode = postcode
        self.regionRaw = region.rawValue
        self.typeRaw = type.rawValue
        self.furnishingRaw = furnishing.rawValue
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.coverPhotoFilename = nil
        self.notes = ""
        self.createdAt = .now
        self.isSample = false
    }

    var region: Region {
        get { Region(rawValue: regionRaw) ?? .unitedKingdom }
        set { regionRaw = newValue.rawValue }
    }

    var type: PropertyType {
        get { PropertyType(rawValue: typeRaw) ?? .flat }
        set { typeRaw = newValue.rawValue }
    }

    var furnishing: Furnishing {
        get { Furnishing(rawValue: furnishingRaw) ?? .unfurnished }
        set { furnishingRaw = newValue.rawValue }
    }

    var displayName: String {
        if !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
        if !addressLine1.isEmpty { return addressLine1 }
        return "Untitled property"
    }

    var fullAddress: String {
        [addressLine1, addressLine2, city, state, postcode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var sortedInspections: [Inspection] {
        inspections.sorted { $0.date > $1.date }
    }

    /// The most recent signed check-in, used as the baseline for a check-out.
    var latestSignedCheckIn: Inspection? {
        sortedInspections.first { $0.kind == .checkIn && $0.status == .signed }
    }

    var latestCheckIn: Inspection? {
        sortedInspections.first { $0.kind == .checkIn }
    }

    var nextComplianceDue: ComplianceItem? {
        complianceItems.filter { $0.expiresAt != nil }.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }.first
    }
}

// MARK: - Inspection

@Model
final class Inspection {
    var id: UUID
    var kindRaw: String
    var statusRaw: String
    var date: Date
    var createdAt: Date
    var signedAt: Date?
    var tenantNames: String
    var tenantEmail: String
    var landlordName: String
    var inspectorName: String
    var tenancyStartDate: Date?
    var tenancyEndDate: Date?
    var depositAmount: Double
    var depositScheme: String
    var depositReference: String
    var generalNotes: String
    var tenantComments: String
    /// For a check-out or interim: the check-in it is compared against.
    var baselineID: UUID?
    var exportCount: Int
    var lastExportHash: String?
    var unlockedByCredit: Bool

    var property: Property?

    @Relationship(deleteRule: .cascade, inverse: \Room.inspection)
    var rooms: [Room] = []

    @Relationship(deleteRule: .cascade, inverse: \MeterReading.inspection)
    var meters: [MeterReading] = []

    @Relationship(deleteRule: .cascade, inverse: \KeyRecord.inspection)
    var keys: [KeyRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \SignatureRecord.inspection)
    var signatures: [SignatureRecord] = []

    init(kind: InspectionKind, date: Date = .now) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.statusRaw = InspectionStatus.draft.rawValue
        self.date = date
        self.createdAt = .now
        self.signedAt = nil
        self.tenantNames = ""
        self.tenantEmail = ""
        self.landlordName = ""
        self.inspectorName = ""
        self.tenancyStartDate = nil
        self.tenancyEndDate = nil
        self.depositAmount = 0
        self.depositScheme = ""
        self.depositReference = ""
        self.generalNotes = ""
        self.tenantComments = ""
        self.baselineID = nil
        self.exportCount = 0
        self.lastExportHash = nil
        self.unlockedByCredit = false
    }

    var kind: InspectionKind {
        get { InspectionKind(rawValue: kindRaw) ?? .checkIn }
        set { kindRaw = newValue.rawValue }
    }

    var status: InspectionStatus {
        get { InspectionStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var isLocked: Bool { status == .signed }

    var region: Region { property?.region ?? .unitedKingdom }

    var title: String { region.reportTitle(for: kind) }

    var sortedRooms: [Room] { rooms.sorted { $0.order < $1.order } }
    var sortedMeters: [MeterReading] { meters.sorted { $0.order < $1.order } }
    var sortedKeys: [KeyRecord] { keys.sorted { $0.order < $1.order } }
    var sortedSignatures: [SignatureRecord] { signatures.sorted { $0.signedAt < $1.signedAt } }

    var baseline: Inspection? {
        guard let baselineID, let property else { return nil }
        return property.inspections.first { $0.id == baselineID }
    }

    var allPhotos: [EvidencePhoto] {
        var result: [EvidencePhoto] = []
        for room in sortedRooms {
            result.append(contentsOf: room.sortedPhotos)
            for item in room.sortedItems { result.append(contentsOf: item.sortedPhotos) }
        }
        for meter in sortedMeters { result.append(contentsOf: meter.photos.sorted { $0.capturedAt < $1.capturedAt }) }
        return result
    }

    var photoCount: Int { allPhotos.count }

    var itemCount: Int { rooms.reduce(0) { $0 + $1.items.count } }

    var completedRoomCount: Int { rooms.filter { $0.isComplete }.count }

    var progress: Double {
        guard !rooms.isEmpty else { return 0 }
        return Double(completedRoomCount) / Double(rooms.count)
    }

    var totalDeductions: Double {
        rooms.reduce(0) { total, room in
            total + room.items.reduce(0) { $0 + ($1.change.isChargeable ? $1.deductionAmount : 0) }
        }
    }

    var chargeableItems: [ChargeableEntry] {
        var result: [ChargeableEntry] = []
        for room in sortedRooms {
            for item in room.sortedItems where item.change.isChargeable {
                result.append(ChargeableEntry(room: room, item: item))
            }
        }
        return result
    }

    var hasTenantSignature: Bool { signatures.contains { $0.role == .tenant } }
    var hasLandlordSignature: Bool { signatures.contains { $0.role == .landlord || $0.role == .agent } }
}

// MARK: - Room

@Model
final class Room {
    var id: UUID
    var name: String
    var kindRaw: String
    var order: Int
    var notes: String
    var summary: String
    var aiGeneratedAt: Date?
    var aiComparedAt: Date?
    var isMarkedComplete: Bool
    /// For check-out rooms: the matching check-in room.
    var baselineRoomID: UUID?

    var inspection: Inspection?

    @Relationship(deleteRule: .cascade, inverse: \RoomItem.room)
    var items: [RoomItem] = []

    @Relationship(deleteRule: .cascade, inverse: \EvidencePhoto.room)
    var photos: [EvidencePhoto] = []

    init(name: String, kind: RoomKind, order: Int) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.order = order
        self.notes = ""
        self.summary = ""
        self.aiGeneratedAt = nil
        self.aiComparedAt = nil
        self.isMarkedComplete = false
        self.baselineRoomID = nil
    }

    var kind: RoomKind {
        get { RoomKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var sortedItems: [RoomItem] { items.sorted { $0.order < $1.order } }
    var sortedPhotos: [EvidencePhoto] { photos.sorted { $0.capturedAt < $1.capturedAt } }

    var allPhotos: [EvidencePhoto] {
        sortedPhotos + sortedItems.flatMap { $0.sortedPhotos }
    }

    var isComplete: Bool {
        isMarkedComplete || (!items.isEmpty && !allPhotos.isEmpty && items.allSatisfy { !$0.itemDescription.isEmpty })
    }

    var baselineRoom: Room? {
        guard let baselineRoomID, let baseline = inspection?.baseline else { return nil }
        return baseline.rooms.first { $0.id == baselineRoomID }
    }

    var issueCount: Int {
        items.filter { $0.change.isChargeable || $0.condition == .damaged || $0.condition == .poor }.count
    }
}

// MARK: - Room item

@Model
final class RoomItem {
    var id: UUID
    var name: String
    var order: Int
    var itemDescription: String
    var conditionRaw: String
    var cleanlinessRaw: String
    var aiGenerated: Bool
    // Check-out comparison
    var baselineItemID: UUID?
    var baselineDescription: String
    var baselineConditionRaw: String
    var baselineCleanlinessRaw: String
    var changeRaw: String
    var changeNote: String
    var deductionAmount: Double

    var room: Room?

    @Relationship(deleteRule: .cascade, inverse: \EvidencePhoto.item)
    var photos: [EvidencePhoto] = []

    init(name: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.order = order
        self.itemDescription = ""
        self.conditionRaw = Condition.good.rawValue
        self.cleanlinessRaw = Cleanliness.clean.rawValue
        self.aiGenerated = false
        self.baselineItemID = nil
        self.baselineDescription = ""
        self.baselineConditionRaw = Condition.notApplicable.rawValue
        self.baselineCleanlinessRaw = Cleanliness.notApplicable.rawValue
        self.changeRaw = ChangeKind.unassessed.rawValue
        self.changeNote = ""
        self.deductionAmount = 0
    }

    var condition: Condition {
        get { Condition(rawValue: conditionRaw) ?? .good }
        set { conditionRaw = newValue.rawValue }
    }

    var cleanliness: Cleanliness {
        get { Cleanliness(rawValue: cleanlinessRaw) ?? .clean }
        set { cleanlinessRaw = newValue.rawValue }
    }

    var baselineCondition: Condition {
        Condition(rawValue: baselineConditionRaw) ?? .notApplicable
    }

    var baselineCleanliness: Cleanliness {
        Cleanliness(rawValue: baselineCleanlinessRaw) ?? .notApplicable
    }

    var change: ChangeKind {
        get { ChangeKind(rawValue: changeRaw) ?? .unassessed }
        set { changeRaw = newValue.rawValue }
    }

    var sortedPhotos: [EvidencePhoto] { photos.sorted { $0.capturedAt < $1.capturedAt } }

    var hasBaseline: Bool { baselineItemID != nil }

    var baselineItem: RoomItem? {
        guard let baselineItemID, let baselineRoom = room?.baselineRoom else { return nil }
        return baselineRoom.items.first { $0.id == baselineItemID }
    }
}

// MARK: - Evidence photo

@Model
final class EvidencePhoto {
    var id: UUID
    var filename: String
    var capturedAt: Date
    var latitude: Double?
    var longitude: Double?
    var sha256: String
    var caption: String
    var isImported: Bool

    var room: Room?
    var item: RoomItem?
    var meter: MeterReading?

    init(filename: String, capturedAt: Date, sha256: String, latitude: Double? = nil, longitude: Double? = nil, isImported: Bool = false) {
        self.id = UUID()
        self.filename = filename
        self.capturedAt = capturedAt
        self.sha256 = sha256
        self.latitude = latitude
        self.longitude = longitude
        self.caption = ""
        self.isImported = isImported
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    var shortHash: String { String(sha256.prefix(12)) }
}

// MARK: - Meter reading

@Model
final class MeterReading {
    var id: UUID
    var typeRaw: String
    var reading: String
    var serialNumber: String
    var location: String
    var order: Int

    var inspection: Inspection?

    @Relationship(deleteRule: .cascade, inverse: \EvidencePhoto.meter)
    var photos: [EvidencePhoto] = []

    init(type: MeterType, order: Int) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.reading = ""
        self.serialNumber = ""
        self.location = ""
        self.order = order
    }

    var type: MeterType {
        get { MeterType(rawValue: typeRaw) ?? .electricity }
        set { typeRaw = newValue.rawValue }
    }
}

// MARK: - Keys

@Model
final class KeyRecord {
    var id: UUID
    var label: String
    var quantity: Int
    var notes: String
    var order: Int

    var inspection: Inspection?

    init(label: String, quantity: Int = 1, order: Int) {
        self.id = UUID()
        self.label = label
        self.quantity = quantity
        self.notes = ""
        self.order = order
    }
}

// MARK: - Signature

@Model
final class SignatureRecord {
    var id: UUID
    var roleRaw: String
    var name: String
    var signedAt: Date
    var imageFilename: String
    var statement: String

    var inspection: Inspection?

    init(role: SignatureRole, name: String, imageFilename: String, statement: String) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.name = name
        self.signedAt = .now
        self.imageFilename = imageFilename
        self.statement = statement
    }

    var role: SignatureRole {
        get { SignatureRole(rawValue: roleRaw) ?? .tenant }
        set { roleRaw = newValue.rawValue }
    }
}

// MARK: - Compliance

@Model
final class ComplianceItem {
    var id: UUID
    var typeRaw: String
    var title: String
    var issuedAt: Date?
    var expiresAt: Date?
    var reminderDaysBefore: Int
    var notes: String
    var documentFilename: String?
    var createdAt: Date

    var property: Property?

    init(type: ComplianceType, title: String? = nil) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.title = title ?? type.label
        self.issuedAt = nil
        self.expiresAt = nil
        self.reminderDaysBefore = 30
        self.notes = ""
        self.documentFilename = nil
        self.createdAt = .now
    }

    var type: ComplianceType {
        get { ComplianceType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.startOfDay(for: expiresAt)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }

    var urgency: ComplianceUrgency {
        guard let days = daysRemaining else { return .unknown }
        if days < 0 { return .overdue }
        if days <= reminderDaysBefore { return .dueSoon }
        return .ok
    }
}

struct ChargeableEntry: Identifiable {
    let room: Room
    let item: RoomItem
    var id: UUID { item.id }
}

enum ComplianceUrgency {
    case overdue, dueSoon, ok, unknown
}

enum SchemaV1 {
    static var models: [any PersistentModel.Type] {
        [Property.self, Inspection.self, Room.self, RoomItem.self, EvidencePhoto.self, MeterReading.self, KeyRecord.self, SignatureRecord.self, ComplianceItem.self]
    }
}
