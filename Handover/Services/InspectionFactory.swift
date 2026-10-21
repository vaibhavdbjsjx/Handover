import Foundation
import SwiftData

/// Creates new inspections with sensible rooms, items, meters and keys.
enum InspectionFactory {
    @discardableResult
    static func makeCheckIn(for property: Property, in context: ModelContext) -> Inspection {
        let inspection = Inspection(kind: .checkIn)
        context.insert(inspection)
        inspection.property = property
        inspection.landlordName = Preferences.companyName.isEmpty ? Preferences.userName : Preferences.companyName
        inspection.inspectorName = Preferences.userName
        inspection.tenancyStartDate = .now

        for (index, room) in RoomKind.defaultRooms(for: property).enumerated() {
            let newRoom = Room(name: room.0, kind: room.1, order: index)
            context.insert(newRoom)
            newRoom.inspection = inspection
            for (itemIndex, itemName) in room.1.defaultItems.enumerated() {
                let item = RoomItem(name: itemName, order: itemIndex)
                context.insert(item)
                item.room = newRoom
            }
        }

        let meterTypes: [MeterType] = [.electricity, .gas, .water]
        for (index, type) in meterTypes.enumerated() {
            let meter = MeterReading(type: type, order: index)
            context.insert(meter)
            meter.inspection = inspection
        }

        for (index, label) in ["Front door keys", "Window keys", "Fobs / access cards"].enumerated() {
            let key = KeyRecord(label: label, quantity: index == 0 ? 2 : 0, order: index)
            context.insert(key)
            key.inspection = inspection
        }
        return inspection
    }

    /// A check-out (or interim) mirrors the baseline so each item can be compared.
    @discardableResult
    static func makeFollowUp(kind: InspectionKind, for property: Property, baseline: Inspection, in context: ModelContext) -> Inspection {
        let inspection = Inspection(kind: kind)
        context.insert(inspection)
        inspection.property = property
        inspection.baselineID = baseline.id
        inspection.tenantNames = baseline.tenantNames
        inspection.tenantEmail = baseline.tenantEmail
        inspection.landlordName = baseline.landlordName
        inspection.inspectorName = Preferences.userName.isEmpty ? baseline.inspectorName : Preferences.userName
        inspection.tenancyStartDate = baseline.tenancyStartDate
        inspection.tenancyEndDate = kind == .checkOut ? .now : nil
        inspection.depositAmount = baseline.depositAmount
        inspection.depositScheme = baseline.depositScheme
        inspection.depositReference = baseline.depositReference

        for baseRoom in baseline.sortedRooms {
            let room = Room(name: baseRoom.name, kind: baseRoom.kind, order: baseRoom.order)
            context.insert(room)
            room.inspection = inspection
            room.baselineRoomID = baseRoom.id
            for baseItem in baseRoom.sortedItems {
                let item = RoomItem(name: baseItem.name, order: baseItem.order)
                context.insert(item)
                item.room = room
                item.baselineItemID = baseItem.id
                item.baselineDescription = baseItem.itemDescription
                item.baselineConditionRaw = baseItem.conditionRaw
                item.baselineCleanlinessRaw = baseItem.cleanlinessRaw
                item.itemDescription = baseItem.itemDescription
                item.conditionRaw = baseItem.conditionRaw
                item.cleanlinessRaw = baseItem.cleanlinessRaw
            }
        }

        for baseMeter in baseline.sortedMeters {
            let meter = MeterReading(type: baseMeter.type, order: baseMeter.order)
            context.insert(meter)
            meter.inspection = inspection
            meter.serialNumber = baseMeter.serialNumber
            meter.location = baseMeter.location
        }

        for baseKey in baseline.sortedKeys {
            let key = KeyRecord(label: baseKey.label, quantity: baseKey.quantity, order: baseKey.order)
            context.insert(key)
            key.inspection = inspection
        }
        return inspection
    }

    static func addRoom(named name: String, kind: RoomKind, to inspection: Inspection, in context: ModelContext) -> Room {
        let order = (inspection.rooms.map(\.order).max() ?? -1) + 1
        let room = Room(name: name, kind: kind, order: order)
        context.insert(room)
        room.inspection = inspection
        for (index, itemName) in kind.defaultItems.enumerated() {
            let item = RoomItem(name: itemName, order: index)
            context.insert(item)
            item.room = room
        }
        return room
    }

    static func addItem(named name: String, to room: Room, in context: ModelContext) -> RoomItem {
        let order = (room.items.map(\.order).max() ?? -1) + 1
        let item = RoomItem(name: name, order: order)
        context.insert(item)
        item.room = room
        return item
    }

    /// Deletes a photo record and its file.
    static func delete(_ photo: EvidencePhoto, in context: ModelContext) {
        PhotoStore.shared.delete(photo.filename)
        context.delete(photo)
    }

    /// Deletes an inspection and every file it owns.
    static func delete(_ inspection: Inspection, in context: ModelContext) {
        for photo in inspection.allPhotos { PhotoStore.shared.delete(photo.filename) }
        for signature in inspection.signatures { PhotoStore.shared.delete(signature.imageFilename) }
        context.delete(inspection)
    }

    static func delete(_ property: Property, in context: ModelContext) {
        for inspection in property.inspections { delete(inspection, in: context) }
        if let cover = property.coverPhotoFilename { PhotoStore.shared.delete(cover) }
        for item in property.complianceItems { ReminderService.cancel(item) }
        context.delete(property)
    }
}
