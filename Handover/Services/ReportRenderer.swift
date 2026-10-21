import UIKit
import SwiftUI
import CoreLocation

/// Renders an inspection as a professional, evidence-grade PDF.
///
/// Layout runs twice: a dry run counts pages so every footer can say
/// "Page x of y", then the real pass draws.
struct ReportRenderer {
    /// Take the snapshot on the main thread; `render()` can then run anywhere.
    let snapshot: ReportSnapshot
    let watermark: Bool

    struct Output {
        let url: URL
        let pageCount: Int
        let sha256: String
    }

    func render() throws -> Output {
        let pageSize = snapshot.region.usesLetterPaper ? CGSize(width: 612, height: 792) : CGSize(width: 595.28, height: 841.89)

        let counter = PDFWriter(pageSize: pageSize, snapshot: snapshot, watermark: watermark, context: nil, totalPages: 0)
        ReportLayout(writer: counter, snapshot: snapshot).build()
        let total = counter.pageNumber

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: snapshot.title,
            kCGPDFContextAuthor as String: snapshot.landlord.isEmpty ? "Handover" : snapshot.landlord,
            kCGPDFContextCreator as String: "Handover for iOS",
            kCGPDFContextSubject as String: snapshot.propertyAddress
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        let data = renderer.pdfData { context in
            let writer = PDFWriter(pageSize: pageSize, snapshot: snapshot, watermark: watermark, context: context, totalPages: total)
            ReportLayout(writer: writer, snapshot: snapshot).build()
        }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(snapshot.filename)
        try data.write(to: url, options: .atomic)
        return Output(url: url, pageCount: total, sha256: PhotoStore.sha256(data))
    }
}

// MARK: - Snapshot

/// A plain copy of everything the report needs, taken on the main thread
/// so rendering can run in the background without touching SwiftData.
struct ReportSnapshot {
    struct Photo {
        let id: UUID
        let filename: String
        let ref: String
        let capturedAt: Date
        let latitude: Double?
        let longitude: Double?
        let sha256: String
        let isImported: Bool
        let label: String
    }

    struct Item {
        let name: String
        let description: String
        let condition: Condition
        let cleanliness: Cleanliness
        let baselineDescription: String
        let baselineCondition: Condition
        let change: ChangeKind
        let changeNote: String
        let deduction: Double
        let photoRefs: [String]
        let photos: [Photo]
        let baselinePhotos: [String]
    }

    struct Room {
        let name: String
        let summary: String
        let notes: String
        let items: [Item]
        let photos: [Photo]
    }

    struct Meter {
        let type: MeterType
        let reading: String
        let serial: String
        let location: String
        let photoRefs: [String]
    }

    struct Key {
        let label: String
        let quantity: Int
        let notes: String
    }

    struct Signature {
        let role: SignatureRole
        let name: String
        let signedAt: Date
        let imageFilename: String
        let statement: String
    }

    let id: UUID
    let kind: InspectionKind
    let region: Region
    let title: String
    let status: InspectionStatus
    let date: Date
    let signedAt: Date?
    let propertyName: String
    let propertyAddress: String
    let propertyDetails: String
    let coverFilename: String?
    let tenants: String
    let landlord: String
    let inspector: String
    let tenancyStart: Date?
    let tenancyEnd: Date?
    let deposit: Double
    let depositScheme: String
    let depositReference: String
    let generalNotes: String
    let tenantComments: String
    let baselineDate: Date?
    let rooms: [Room]
    let meters: [Meter]
    let keys: [Key]
    let signatures: [Signature]
    let allPhotos: [Photo]
    let totalDeductions: Double
    let companyName: String
    let companyEmail: String
    let companyPhone: String
    let logoFilename: String?

    var isFollowUp: Bool { kind != .checkIn && baselineDate != nil }

    var manifestHash: String {
        PhotoStore.sha256(allPhotos.map(\.sha256).joined(separator: "\n"))
    }

    var reportID: String { String(id.uuidString.prefix(8)).uppercased() }

    var filename: String {
        let safeName = propertyName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let dateString = date.formatted(.iso8601.year().month().day())
        return "\(region.shortName(for: kind))-\(safeName.isEmpty ? "Property" : safeName)-\(dateString).pdf"
    }

    init(inspection: Inspection) {
        let region = inspection.region
        let property = inspection.property

        var refCounter = 0
        var refs: [UUID: String] = [:]
        func makePhoto(_ photo: EvidencePhoto, label: String) -> Photo {
            if refs[photo.id] == nil {
                refCounter += 1
                refs[photo.id] = "P\(refCounter)"
            }
            return Photo(id: photo.id, filename: photo.filename, ref: refs[photo.id] ?? "", capturedAt: photo.capturedAt, latitude: photo.latitude, longitude: photo.longitude, sha256: photo.sha256, isImported: photo.isImported, label: label)
        }

        var rooms: [Room] = []
        var all: [Photo] = []
        for room in inspection.sortedRooms {
            let roomPhotos = room.sortedPhotos.map { makePhoto($0, label: room.name) }
            all.append(contentsOf: roomPhotos)
            var items: [Item] = []
            var itemPhotoList: [Photo] = []
            for item in room.sortedItems {
                let photos = item.sortedPhotos.map { makePhoto($0, label: "\(room.name) · \(item.name)") }
                itemPhotoList.append(contentsOf: photos)
                let baselinePhotos = item.baselineItem?.sortedPhotos.map(\.filename) ?? []
                items.append(Item(
                    name: item.name,
                    description: item.itemDescription,
                    condition: item.condition,
                    cleanliness: item.cleanliness,
                    baselineDescription: item.baselineDescription,
                    baselineCondition: item.baselineCondition,
                    change: item.change,
                    changeNote: item.changeNote,
                    deduction: item.change.isChargeable ? item.deductionAmount : 0,
                    photoRefs: photos.map(\.ref),
                    photos: photos,
                    baselinePhotos: baselinePhotos
                ))
            }
            all.append(contentsOf: itemPhotoList)
            rooms.append(Room(name: room.name, summary: room.summary, notes: room.notes, items: items, photos: roomPhotos + itemPhotoList))
        }

        var meters: [Meter] = []
        for meter in inspection.sortedMeters {
            let photos = meter.photos.sorted { $0.capturedAt < $1.capturedAt }.map { makePhoto($0, label: "\(meter.type.label) meter") }
            all.append(contentsOf: photos)
            meters.append(Meter(type: meter.type, reading: meter.reading, serial: meter.serialNumber, location: meter.location, photoRefs: photos.map(\.ref)))
        }

        self.id = inspection.id
        self.kind = inspection.kind
        self.region = region
        self.title = inspection.title
        self.status = inspection.status
        self.date = inspection.date
        self.signedAt = inspection.signedAt
        self.propertyName = property?.displayName ?? "Property"
        self.propertyAddress = property?.fullAddress ?? ""
        if let property {
            self.propertyDetails = "\(property.type.label) · \(property.bedrooms) bed · \(property.bathrooms) bath · \(property.furnishing.label)"
        } else {
            self.propertyDetails = ""
        }
        self.coverFilename = property?.coverPhotoFilename
        self.tenants = inspection.tenantNames
        self.landlord = inspection.landlordName
        self.inspector = inspection.inspectorName
        self.tenancyStart = inspection.tenancyStartDate
        self.tenancyEnd = inspection.tenancyEndDate
        self.deposit = inspection.depositAmount
        self.depositScheme = inspection.depositScheme
        self.depositReference = inspection.depositReference
        self.generalNotes = inspection.generalNotes
        self.tenantComments = inspection.tenantComments
        self.baselineDate = inspection.baseline?.date
        self.rooms = rooms
        self.meters = meters
        self.keys = inspection.sortedKeys.filter { !$0.label.isEmpty }.map { Key(label: $0.label, quantity: $0.quantity, notes: $0.notes) }
        self.signatures = inspection.sortedSignatures.map { Signature(role: $0.role, name: $0.name, signedAt: $0.signedAt, imageFilename: $0.imageFilename, statement: $0.statement) }
        self.allPhotos = all
        self.totalDeductions = inspection.totalDeductions
        self.companyName = Preferences.companyName
        self.companyEmail = Preferences.userEmail
        self.companyPhone = Preferences.userPhone
        self.logoFilename = Preferences.logoFilename
    }
}

// MARK: - Style

enum ReportStyle {
    static let evergreen = UIColor(red: 0.118, green: 0.361, blue: 0.290, alpha: 1)
    static let deepGreen = UIColor(red: 0.043, green: 0.141, blue: 0.118, alpha: 1)
    static let gold = UIColor(red: 0.690, green: 0.541, blue: 0.243, alpha: 1)
    static let ink = UIColor(red: 0.071, green: 0.106, blue: 0.165, alpha: 1)
    static let muted = UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
    static let rule = UIColor(red: 0.88, green: 0.89, blue: 0.90, alpha: 1)
    static let tint = UIColor(red: 0.955, green: 0.965, blue: 0.958, alpha: 1)

    static func serif(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    static func sans(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func mono(_ size: CGFloat) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func text(_ string: String, font: UIFont, color: UIColor = ink, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 1.5) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    static func conditionColor(_ condition: Condition) -> UIColor {
        UIColor(condition.color)
    }

    static func changeColor(_ change: ChangeKind) -> UIColor {
        UIColor(change.color)
    }
}

// MARK: - Writer

/// A cursor-based page writer. With no context it only measures and counts pages.
final class PDFWriter {
    let pageSize: CGSize
    let margin: CGFloat = 40
    let footerHeight: CGFloat = 34
    let snapshot: ReportSnapshot
    let watermark: Bool
    let context: UIGraphicsPDFRendererContext?
    let totalPages: Int

    private(set) var pageNumber = 0
    var y: CGFloat = 0

    init(pageSize: CGSize, snapshot: ReportSnapshot, watermark: Bool, context: UIGraphicsPDFRendererContext?, totalPages: Int) {
        self.pageSize = pageSize
        self.snapshot = snapshot
        self.watermark = watermark
        self.context = context
        self.totalPages = totalPages
    }

    var isDrawing: Bool { context != nil }
    var contentWidth: CGFloat { pageSize.width - margin * 2 }
    var left: CGFloat { margin }
    var bottomLimit: CGFloat { pageSize.height - margin - footerHeight }
    var remaining: CGFloat { bottomLimit - y }

    func newPage(withChrome: Bool = true) {
        pageNumber += 1
        context?.beginPage()
        y = margin
        if isDrawing {
            if watermark { drawWatermark() }
            if withChrome { drawFooter() }
        }
        if withChrome { drawRunningHeader() }
    }

    func ensureSpace(_ height: CGFloat) {
        if y + height > bottomLimit { newPage() }
    }

    // MARK: Primitives

    func measure(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
        guard text.length > 0 else { return 0 }
        let rect = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return ceil(rect.height)
    }

    @discardableResult
    func draw(_ text: NSAttributedString, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let height = measure(text, width: width)
        if isDrawing {
            text.draw(with: CGRect(x: x, y: y, width: width, height: height + 2), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
        return height
    }

    /// Draws a paragraph at the cursor, splitting across pages only between paragraphs.
    func paragraph(_ text: NSAttributedString, spacingAfter: CGFloat = 8) {
        let height = measure(text, width: contentWidth)
        if height > bottomLimit - margin - 40 {
            // Very long text: draw what fits line by line via chunks.
            for line in text.string.components(separatedBy: "\n") {
                let attributed = NSAttributedString(string: line, attributes: text.attributes(at: 0, effectiveRange: nil))
                paragraph(attributed, spacingAfter: 2)
            }
            y += spacingAfter
            return
        }
        ensureSpace(height)
        draw(text, x: left, y: y, width: contentWidth)
        y += height + spacingAfter
    }

    func fill(_ rect: CGRect, color: UIColor, radius: CGFloat = 0) {
        guard isDrawing else { return }
        color.setFill()
        if radius > 0 {
            UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
        } else {
            UIRectFill(rect)
        }
    }

    func stroke(_ rect: CGRect, color: UIColor, width: CGFloat = 0.5, radius: CGFloat = 0) {
        guard isDrawing else { return }
        color.setStroke()
        let path = radius > 0 ? UIBezierPath(roundedRect: rect, cornerRadius: radius) : UIBezierPath(rect: rect)
        path.lineWidth = width
        path.stroke()
    }

    func line(from start: CGPoint, to end: CGPoint, color: UIColor = ReportStyle.rule, width: CGFloat = 0.5) {
        guard isDrawing else { return }
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    func image(_ image: UIImage, in rect: CGRect, radius: CGFloat = 4) {
        guard isDrawing, let cg = context?.cgContext else { return }
        cg.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
        let size = image.size
        let scale = max(rect.width / max(size.width, 1), rect.height / max(size.height, 1))
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        image.draw(in: CGRect(origin: origin, size: drawSize))
        cg.restoreGState()
    }

    func imageFit(_ image: UIImage, in rect: CGRect) {
        guard isDrawing else { return }
        let size = image.size
        let scale = min(rect.width / max(size.width, 1), rect.height / max(size.height, 1))
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: rect.minX, y: rect.midY - drawSize.height / 2)
        image.draw(in: CGRect(origin: origin, size: drawSize))
    }

    /// A JPEG-backed copy so the PDF embeds compressed image data.
    func reportImage(_ filename: String, maxPixel: CGFloat = 1100) -> UIImage? {
        guard isDrawing else { return nil }
        guard let thumb = PhotoStore.shared.thumbnail(filename, maxPixel: maxPixel),
              let data = thumb.jpegData(compressionQuality: 0.72) else { return nil }
        return UIImage(data: data)
    }

    // MARK: Chrome

    private func drawRunningHeader() {
        let label = ReportStyle.text(snapshot.title.uppercased(), font: ReportStyle.sans(7.5, .semibold), color: ReportStyle.muted)
        let address = ReportStyle.text(snapshot.propertyName, font: ReportStyle.sans(7.5), color: ReportStyle.muted, alignment: .right)
        draw(label, x: left, y: y, width: contentWidth / 2)
        draw(address, x: left + contentWidth / 2, y: y, width: contentWidth / 2)
        line(from: CGPoint(x: left, y: y + 14), to: CGPoint(x: left + contentWidth, y: y + 14))
        y += 28
    }

    private func drawFooter() {
        let footerY = pageSize.height - margin - 12
        line(from: CGPoint(x: left, y: footerY - 8), to: CGPoint(x: left + contentWidth, y: footerY - 8))
        let leftText = ReportStyle.text("Handover · Report \(snapshot.reportID) · \(snapshot.date.formatted(date: .abbreviated, time: .omitted))", font: ReportStyle.sans(7.5), color: ReportStyle.muted)
        let pageText = ReportStyle.text(totalPages > 0 ? "Page \(pageNumber) of \(totalPages)" : "Page \(pageNumber)", font: ReportStyle.sans(7.5, .semibold), color: ReportStyle.muted, alignment: .right)
        draw(leftText, x: left, y: footerY, width: contentWidth * 0.7)
        draw(pageText, x: left + contentWidth * 0.7, y: footerY, width: contentWidth * 0.3)
    }

    private func drawWatermark() {
        guard let cg = context?.cgContext else { return }
        cg.saveGState()
        cg.translateBy(x: pageSize.width / 2, y: pageSize.height / 2)
        cg.rotate(by: -.pi / 5)
        let text = ReportStyle.text("PREVIEW · HANDOVER", font: ReportStyle.serif(54, .bold), color: ReportStyle.gold.withAlphaComponent(0.13), alignment: .center)
        let width: CGFloat = 700
        let height = measure(text, width: width)
        text.draw(with: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), options: [.usesLineFragmentOrigin], context: nil)
        cg.restoreGState()
    }
}
