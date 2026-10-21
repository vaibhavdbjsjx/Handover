import UIKit

/// Lays out every section of the report onto a `PDFWriter`.
struct ReportLayout {
    let writer: PDFWriter
    let snapshot: ReportSnapshot

    private var region: Region { snapshot.region }
    private var checkInName: String { region.shortName(for: .checkIn) }

    func build() {
        coverPage()
        writer.newPage()
        aboutSection()
        metersAndKeysSection()
        for room in snapshot.rooms {
            roomSection(room)
        }
        if snapshot.isFollowUp && snapshot.kind == .checkOut {
            claimSection()
        }
        notesSection()
        signatureSection()
        evidenceAppendix()
    }

    // MARK: Cover

    private func coverPage() {
        writer.newPage(withChrome: false)
        let w = writer
        let bandHeight: CGFloat = 250
        w.fill(CGRect(x: 0, y: 0, width: w.pageSize.width, height: bandHeight), color: ReportStyle.deepGreen)
        w.fill(CGRect(x: 0, y: bandHeight - 4, width: w.pageSize.width, height: 4), color: ReportStyle.gold)

        var y: CGFloat = 46
        let brand = ReportStyle.text("H A N D O V E R", font: ReportStyle.sans(9, .bold), color: ReportStyle.gold)
        w.draw(brand, x: w.left, y: y, width: 200)

        if let logo = snapshot.logoFilename, w.isDrawing, let image = PhotoStore.shared.image(logo) {
            w.imageFit(image, in: CGRect(x: w.left + w.contentWidth - 110, y: y - 6, width: 110, height: 40))
        }

        y += 40
        let title = ReportStyle.text(snapshot.title, font: ReportStyle.serif(30, .bold), color: .white)
        y += w.draw(title, x: w.left, y: y, width: w.contentWidth) + 10
        let address = ReportStyle.text(snapshot.propertyAddress.isEmpty ? snapshot.propertyName : snapshot.propertyAddress, font: ReportStyle.sans(12, .medium), color: UIColor.white.withAlphaComponent(0.85))
        y += w.draw(address, x: w.left, y: y, width: w.contentWidth) + 6
        if !snapshot.propertyDetails.isEmpty {
            let details = ReportStyle.text(snapshot.propertyDetails, font: ReportStyle.sans(9.5), color: UIColor.white.withAlphaComponent(0.65))
            w.draw(details, x: w.left, y: y, width: w.contentWidth)
        }

        y = bandHeight + 28
        if let cover = snapshot.coverFilename, let image = w.reportImage(cover, maxPixel: 1400) {
            w.image(image, in: CGRect(x: w.left, y: y, width: w.contentWidth, height: 190), radius: 8)
            y += 190 + 24
        } else if snapshot.coverFilename != nil {
            y += 190 + 24
        }

        // Details grid
        var rows: [(String, String)] = [
            ("Report", snapshot.title),
            ("Inspection date", snapshot.date.formatted(date: .long, time: .omitted)),
            ("Tenant(s)", snapshot.tenants.isEmpty ? "Not recorded" : snapshot.tenants),
            ("Landlord", snapshot.landlord.isEmpty ? "Not recorded" : snapshot.landlord),
            ("Inspected by", snapshot.inspector.isEmpty ? "Not recorded" : snapshot.inspector)
        ]
        if let start = snapshot.tenancyStart { rows.append(("Tenancy start", start.formatted(date: .long, time: .omitted))) }
        if let end = snapshot.tenancyEnd { rows.append(("Tenancy end", end.formatted(date: .long, time: .omitted))) }
        if snapshot.deposit > 0 {
            var depositText = snapshot.deposit.currency(region)
            if !snapshot.depositScheme.isEmpty { depositText += " · \(snapshot.depositScheme)" }
            if !snapshot.depositReference.isEmpty { depositText += " · Ref \(snapshot.depositReference)" }
            rows.append((region.depositTerm.capitalized, depositText))
        }
        if let baselineDate = snapshot.baselineDate, snapshot.kind != .checkIn {
            rows.append(("Compared with", "\(region.reportTitle(for: .checkIn)) of \(baselineDate.formatted(date: .long, time: .omitted))"))
        }
        rows.append(("Report ID", snapshot.reportID))

        let labelWidth: CGFloat = 120
        for (label, value) in rows {
            let labelText = ReportStyle.text(label.uppercased(), font: ReportStyle.sans(7.5, .semibold), color: ReportStyle.muted)
            let valueText = ReportStyle.text(value, font: ReportStyle.sans(10.5, .medium))
            let height = max(w.measure(valueText, width: w.contentWidth - labelWidth), 14)
            w.draw(labelText, x: w.left, y: y + 2, width: labelWidth)
            w.draw(valueText, x: w.left + labelWidth, y: y, width: w.contentWidth - labelWidth)
            y += height + 7
            w.line(from: CGPoint(x: w.left, y: y - 3), to: CGPoint(x: w.left + w.contentWidth, y: y - 3))
        }

        // At a glance
        y += 16
        var stats: [(String, String)] = [
            ("\(snapshot.rooms.count)", "Rooms"),
            ("\(snapshot.rooms.reduce(0) { $0 + $1.items.count })", "Items"),
            ("\(snapshot.allPhotos.count)", "Photos")
        ]
        if snapshot.isFollowUp && snapshot.kind == .checkOut {
            stats.append((snapshot.totalDeductions.currency(region), "Proposed deductions"))
        } else {
            stats.append((snapshot.signatures.isEmpty ? "Unsigned" : "\(snapshot.signatures.count)", "Signatures"))
        }
        let tileGap: CGFloat = 10
        let tileWidth = (w.contentWidth - tileGap * CGFloat(stats.count - 1)) / CGFloat(stats.count)
        if y + 62 < w.pageSize.height - w.margin {
            for (index, stat) in stats.enumerated() {
                let x = w.left + CGFloat(index) * (tileWidth + tileGap)
                let rect = CGRect(x: x, y: y, width: tileWidth, height: 58)
                w.fill(rect, color: ReportStyle.tint, radius: 6)
                w.draw(ReportStyle.text(stat.0, font: ReportStyle.serif(17, .bold), color: ReportStyle.evergreen), x: x + 12, y: y + 10, width: tileWidth - 24)
                w.draw(ReportStyle.text(stat.1.uppercased(), font: ReportStyle.sans(7, .semibold), color: ReportStyle.muted), x: x + 12, y: y + 36, width: tileWidth - 24)
            }
        }

        let contactParts = [snapshot.companyName, snapshot.companyEmail, snapshot.companyPhone].filter { !$0.isEmpty }
        if !contactParts.isEmpty {
            let contact = ReportStyle.text(contactParts.joined(separator: "  ·  "), font: ReportStyle.sans(8.5), color: ReportStyle.muted, alignment: .center)
            w.draw(contact, x: w.left, y: w.pageSize.height - w.margin - 12, width: w.contentWidth)
        }
    }

    // MARK: Section headings

    private func heading(_ title: String, subtitle: String? = nil) {
        let titleText = ReportStyle.text(title, font: ReportStyle.serif(18, .bold), color: ReportStyle.ink)
        let titleHeight = writer.measure(titleText, width: writer.contentWidth)
        var needed = titleHeight + 22
        var subtitleText: NSAttributedString?
        if let subtitle {
            let text = ReportStyle.text(subtitle, font: ReportStyle.sans(9), color: ReportStyle.muted)
            subtitleText = text
            needed += writer.measure(text, width: writer.contentWidth) + 4
        }
        writer.ensureSpace(needed + 60)
        writer.fill(CGRect(x: writer.left, y: writer.y + 3, width: 3, height: titleHeight - 4), color: ReportStyle.gold)
        writer.draw(titleText, x: writer.left + 10, y: writer.y, width: writer.contentWidth - 10)
        writer.y += titleHeight + 4
        if let subtitleText {
            writer.y += writer.draw(subtitleText, x: writer.left + 10, y: writer.y, width: writer.contentWidth - 10) + 4
        }
        writer.y += 10
    }

    // MARK: About

    private func aboutSection() {
        heading("About this report")
        let intro: String
        switch snapshot.kind {
        case .checkIn:
            intro = "This report records the condition, cleanliness and contents of the property at the start of the tenancy. It will be used as the reference point when the tenancy ends. Please read it carefully and record anything you disagree with in the tenant comments before signing."
        case .checkOut:
            intro = "This report records the condition and cleanliness of the property at the end of the tenancy, compared item by item with the \(region.reportTitle(for: .checkIn).lowercased()). Changes are classed as fair wear and tear, cleaning, damage or missing. Proposed deductions are a starting point for agreement and are not a final determination."
        case .interim:
            intro = "This report records the condition of the property during the tenancy, compared with the \(region.reportTitle(for: .checkIn).lowercased())."
        }
        writer.paragraph(ReportStyle.text(intro, font: ReportStyle.sans(9.5), lineSpacing: 2.5), spacingAfter: 14)

        // Condition scale
        let rowHeight: CGFloat = 20
        writer.ensureSpace(rowHeight * 6 + 30)
        writer.draw(ReportStyle.text("CONDITION SCALE", font: ReportStyle.sans(7.5, .bold), color: ReportStyle.muted), x: writer.left, y: writer.y, width: 200)
        writer.y += 14
        for condition in Condition.rated {
            let y = writer.y
            writer.fill(CGRect(x: writer.left, y: y + 5, width: 8, height: 8), color: ReportStyle.conditionColor(condition), radius: 4)
            writer.draw(ReportStyle.text(condition.label, font: ReportStyle.sans(9, .semibold)), x: writer.left + 16, y: y + 2, width: 80)
            writer.draw(ReportStyle.text(condition.definition, font: ReportStyle.sans(9), color: ReportStyle.muted), x: writer.left + 100, y: y + 2, width: writer.contentWidth - 100)
            writer.y += rowHeight
        }
        writer.y += 12

        let evidence = "Photographs were taken in the Handover app at the time shown beside each one. Each photo was fingerprinted with a SHA-256 hash when it was captured, listed in the evidence appendix, so any later alteration can be detected. Photos marked \"imported\" were added from the device's photo library rather than captured during the inspection. Photo references (for example P12) link items to their photographs."
        writer.paragraph(ReportStyle.text(evidence, font: ReportStyle.sans(8.5), color: ReportStyle.muted, lineSpacing: 2), spacingAfter: 18)
    }

    // MARK: Meters and keys

    private func metersAndKeysSection() {
        let meters = snapshot.meters.filter { !$0.reading.isEmpty || !$0.serial.isEmpty || !$0.photoRefs.isEmpty }
        guard !meters.isEmpty || !snapshot.keys.isEmpty else { return }
        heading("Meters & keys")
        if !meters.isEmpty {
            let columns: [(String, CGFloat)] = [("Meter", 0.18), ("Reading", 0.2), ("Serial number", 0.24), ("Location", 0.24), ("Photos", 0.14)]
            tableHeader(columns)
            for meter in meters {
                tableRow(columns, values: [
                    ReportStyle.text(meter.type.label, font: ReportStyle.sans(9, .semibold)),
                    ReportStyle.text(meter.reading.isEmpty ? "—" : meter.reading, font: ReportStyle.mono(9.5)),
                    ReportStyle.text(meter.serial.isEmpty ? "—" : meter.serial, font: ReportStyle.sans(9)),
                    ReportStyle.text(meter.location.isEmpty ? "—" : meter.location, font: ReportStyle.sans(9)),
                    ReportStyle.text(meter.photoRefs.joined(separator: ", "), font: ReportStyle.sans(8.5), color: ReportStyle.evergreen)
                ], header: columns)
            }
            writer.y += 14
        }
        if !snapshot.keys.isEmpty {
            let columns: [(String, CGFloat)] = [("Keys & access", 0.6), ("Quantity", 0.4)]
            tableHeader(columns)
            for key in snapshot.keys {
                tableRow(columns, values: [
                    ReportStyle.text(key.label, font: ReportStyle.sans(9, .semibold)),
                    ReportStyle.text("\(key.quantity)", font: ReportStyle.sans(9))
                ], header: columns)
            }
            writer.y += 18
        }
    }

    // MARK: Tables

    private func tableHeader(_ columns: [(String, CGFloat)]) {
        let height: CGFloat = 20
        writer.ensureSpace(height + 30)
        writer.fill(CGRect(x: writer.left, y: writer.y, width: writer.contentWidth, height: height), color: ReportStyle.deepGreen, radius: 3)
        var x = writer.left
        for (title, fraction) in columns {
            let width = writer.contentWidth * fraction
            writer.draw(ReportStyle.text(title.uppercased(), font: ReportStyle.sans(7, .bold), color: .white), x: x + 6, y: writer.y + 6, width: width - 12)
            x += width
        }
        writer.y += height
    }

    private func tableRow(_ columns: [(String, CGFloat)], values: [NSAttributedString], header: [(String, CGFloat)], shaded: Bool = false) {
        let padding: CGFloat = 6
        var height: CGFloat = 0
        for (index, value) in values.enumerated() {
            let width = writer.contentWidth * columns[index].1 - padding * 2
            height = max(height, writer.measure(value, width: width))
        }
        height += padding * 2
        if writer.y + height > writer.bottomLimit {
            writer.newPage()
            tableHeader(header)
        }
        if shaded {
            writer.fill(CGRect(x: writer.left, y: writer.y, width: writer.contentWidth, height: height), color: ReportStyle.tint)
        }
        var x = writer.left
        for (index, value) in values.enumerated() {
            let width = writer.contentWidth * columns[index].1
            writer.draw(value, x: x + padding, y: writer.y + padding, width: width - padding * 2)
            x += width
        }
        writer.y += height
        writer.line(from: CGPoint(x: writer.left, y: writer.y), to: CGPoint(x: writer.left + writer.contentWidth, y: writer.y))
    }

    // MARK: Rooms

    private func roomSection(_ room: ReportSnapshot.Room) {
        writer.ensureSpace(140)
        heading(room.name, subtitle: "\(room.items.count) items · \(room.photos.count) photos")
        if !room.summary.isEmpty {
            writer.paragraph(ReportStyle.text(room.summary, font: ReportStyle.serif(10, .regular), color: ReportStyle.ink, lineSpacing: 2.5), spacingAfter: 10)
        }

        if snapshot.isFollowUp {
            let columns: [(String, CGFloat)] = [("Item", 0.17), ("At \(checkInName.lowercased())", 0.27), ("Now", 0.30), ("Assessment", 0.26)]
            tableHeader(columns)
            for (index, item) in room.items.enumerated() {
                tableRow(columns, values: [
                    itemNameCell(item),
                    descriptionCell(item.baselineDescription, condition: item.baselineCondition, cleanliness: nil),
                    descriptionCell(item.description, condition: item.condition, cleanliness: item.cleanliness),
                    changeCell(item)
                ], header: columns, shaded: index % 2 == 1)
            }
        } else {
            let columns: [(String, CGFloat)] = [("Item", 0.2), ("Description", 0.5), ("Condition", 0.15), ("Cleanliness", 0.15)]
            tableHeader(columns)
            for (index, item) in room.items.enumerated() {
                tableRow(columns, values: [
                    itemNameCell(item),
                    ReportStyle.text(item.description.isEmpty ? "No description recorded." : item.description, font: ReportStyle.sans(9), color: item.description.isEmpty ? ReportStyle.muted : ReportStyle.ink, lineSpacing: 1.5),
                    ReportStyle.text(item.condition.label, font: ReportStyle.sans(9, .semibold), color: ReportStyle.conditionColor(item.condition)),
                    ReportStyle.text(item.cleanliness.label, font: ReportStyle.sans(9))
                ], header: columns, shaded: index % 2 == 1)
            }
        }
        writer.y += 10

        if !room.notes.isEmpty {
            writer.paragraph(ReportStyle.text("Notes: \(room.notes)", font: ReportStyle.sans(9), color: ReportStyle.muted), spacingAfter: 10)
        }

        photoGrid(room.photos)
        writer.y += 16
    }

    private func itemNameCell(_ item: ReportSnapshot.Item) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: ReportStyle.text(item.name, font: ReportStyle.sans(9, .semibold)))
        if !item.photoRefs.isEmpty {
            result.append(ReportStyle.text("\n" + item.photoRefs.joined(separator: ", "), font: ReportStyle.sans(7.5, .medium), color: ReportStyle.evergreen))
        }
        return result
    }

    private func descriptionCell(_ text: String, condition: Condition, cleanliness: Cleanliness?) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: ReportStyle.text(text.isEmpty ? "Not recorded." : text, font: ReportStyle.sans(8.5), color: text.isEmpty ? ReportStyle.muted : ReportStyle.ink))
        var meta = condition.label
        if let cleanliness, cleanliness != .notApplicable { meta += " · \(cleanliness.label)" }
        result.append(ReportStyle.text("\n" + meta, font: ReportStyle.sans(7.5, .semibold), color: ReportStyle.conditionColor(condition)))
        return result
    }

    private func changeCell(_ item: ReportSnapshot.Item) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: ReportStyle.text(item.change.label, font: ReportStyle.sans(8.5, .bold), color: ReportStyle.changeColor(item.change)))
        if !item.changeNote.isEmpty {
            result.append(ReportStyle.text("\n" + item.changeNote, font: ReportStyle.sans(8.5)))
        }
        if item.deduction > 0 {
            result.append(ReportStyle.text("\nProposed: " + item.deduction.currency(region), font: ReportStyle.sans(8.5, .semibold)))
        }
        return result
    }

    private func photoGrid(_ photos: [ReportSnapshot.Photo]) {
        guard !photos.isEmpty else { return }
        let columns = 3
        let gap: CGFloat = 8
        let cellWidth = (writer.contentWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let imageHeight = cellWidth * 0.75
        let captionHeight: CGFloat = 26
        let rowHeight = imageHeight + captionHeight + gap

        var index = 0
        while index < photos.count {
            writer.ensureSpace(rowHeight)
            let rowY = writer.y
            for column in 0..<columns where index < photos.count {
                let photo = photos[index]
                let x = writer.left + CGFloat(column) * (cellWidth + gap)
                let rect = CGRect(x: x, y: rowY, width: cellWidth, height: imageHeight)
                if let image = writer.reportImage(photo.filename) {
                    writer.image(image, in: rect, radius: 4)
                } else {
                    writer.fill(rect, color: ReportStyle.tint, radius: 4)
                }
                // Reference badge
                let badge = ReportStyle.text(photo.ref, font: ReportStyle.sans(7, .bold), color: .white)
                let badgeWidth = ceil(badge.size().width) + 10
                writer.fill(CGRect(x: x + 5, y: rowY + 5, width: badgeWidth, height: 12), color: ReportStyle.deepGreen.withAlphaComponent(0.85), radius: 3)
                writer.draw(badge, x: x + 10, y: rowY + 6.5, width: badgeWidth - 5)

                var caption = "\(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))"
                if photo.isImported { caption += " · imported" }
                let captionText = NSMutableAttributedString(attributedString: ReportStyle.text(caption, font: ReportStyle.sans(7, .semibold), color: ReportStyle.ink))
                captionText.append(ReportStyle.text("\n" + photo.label, font: ReportStyle.sans(7), color: ReportStyle.muted))
                writer.draw(captionText, x: x, y: rowY + imageHeight + 3, width: cellWidth)
                index += 1
            }
            writer.y = rowY + rowHeight
        }
    }

    // MARK: Claim

    private func claimSection() {
        let chargeable = snapshot.rooms.flatMap { room in room.items.filter { $0.change.isChargeable }.map { (room.name, $0) } }
        writer.newPage()
        heading("\(region.depositTerm.capitalized) claim summary", subtitle: "Items assessed as cleaning, damage or missing, with the evidence for each.")

        let columns: [(String, CGFloat)] = [("Room · item", 0.3), ("Assessment", 0.5), ("Amount", 0.2)]
        tableHeader(columns)
        if chargeable.isEmpty {
            tableRow(columns, values: [
                ReportStyle.text("No chargeable items", font: ReportStyle.sans(9, .semibold)),
                ReportStyle.text("No deductions are proposed.", font: ReportStyle.sans(9)),
                ReportStyle.text(0.0.currency(region), font: ReportStyle.sans(9), alignment: .right)
            ], header: columns)
        }
        for (roomName, item) in chargeable {
            let assessment = NSMutableAttributedString(attributedString: ReportStyle.text(item.change.label, font: ReportStyle.sans(8.5, .bold), color: ReportStyle.changeColor(item.change)))
            if !item.changeNote.isEmpty { assessment.append(ReportStyle.text("\n" + item.changeNote, font: ReportStyle.sans(8.5))) }
            tableRow(columns, values: [
                ReportStyle.text("\(roomName) · \(item.name)", font: ReportStyle.sans(9, .semibold)),
                assessment,
                ReportStyle.text(item.deduction.currency(region), font: ReportStyle.sans(9, .semibold), alignment: .right)
            ], header: columns)
        }

        // Totals
        writer.ensureSpace(80)
        writer.y += 8
        let totals: [(String, String, Bool)] = [
            ("\(region.depositTerm.capitalized) held", snapshot.deposit.currency(region), false),
            ("Proposed deductions", snapshot.totalDeductions.currency(region), false),
            ("Balance to return to tenant", max(0, snapshot.deposit - snapshot.totalDeductions).currency(region), true)
        ]
        for (label, value, bold) in totals {
            let font = bold ? ReportStyle.sans(10.5, .bold) : ReportStyle.sans(9.5)
            writer.draw(ReportStyle.text(label, font: font), x: writer.left + writer.contentWidth * 0.4, y: writer.y, width: writer.contentWidth * 0.4)
            writer.draw(ReportStyle.text(value, font: font, alignment: .right), x: writer.left + writer.contentWidth * 0.8, y: writer.y, width: writer.contentWidth * 0.2)
            writer.y += bold ? 20 : 16
        }
        writer.y += 10
        writer.paragraph(ReportStyle.text("Deductions allow for fair wear and tear, the age and expected lifespan of each item, and the length of the tenancy. Where the parties cannot agree, the evidence in this report may be submitted to the \(snapshot.depositScheme.isEmpty ? "relevant deposit scheme or tribunal" : snapshot.depositScheme).", font: ReportStyle.sans(8.5), color: ReportStyle.muted, lineSpacing: 2), spacingAfter: 16)

        // Side-by-side evidence
        for (roomName, item) in chargeable {
            let half = (writer.contentWidth - 10) / 2
            let imageHeight = half * 0.7
            writer.ensureSpace(imageHeight + 60)
            writer.draw(ReportStyle.text("\(roomName) · \(item.name)", font: ReportStyle.sans(10, .bold)), x: writer.left, y: writer.y, width: writer.contentWidth)
            writer.y += 16
            let before = item.baselinePhotos.first
            let after = item.photos.first?.filename
            let labels = ["At \(checkInName.lowercased())", "Now"]
            for (index, filename) in [before, after].enumerated() {
                let x = writer.left + CGFloat(index) * (half + 10)
                let rect = CGRect(x: x, y: writer.y, width: half, height: imageHeight)
                if let filename, let image = writer.reportImage(filename) {
                    writer.image(image, in: rect, radius: 4)
                } else {
                    writer.fill(rect, color: ReportStyle.tint, radius: 4)
                    writer.draw(ReportStyle.text("No close-up photo", font: ReportStyle.sans(8), color: ReportStyle.muted, alignment: .center), x: x, y: rect.midY - 5, width: half)
                }
                writer.draw(ReportStyle.text(labels[index].uppercased(), font: ReportStyle.sans(7, .bold), color: ReportStyle.muted), x: x, y: writer.y + imageHeight + 4, width: half)
            }
            writer.y += imageHeight + 24
        }
    }

    // MARK: Notes

    private func notesSection() {
        guard !snapshot.generalNotes.isEmpty else { return }
        heading("General notes")
        writer.paragraph(ReportStyle.text(snapshot.generalNotes, font: ReportStyle.sans(9.5), lineSpacing: 2.5), spacingAfter: 16)
    }

    // MARK: Signatures

    private func signatureSection() {
        writer.ensureSpace(260)
        heading("Declarations & signatures")

        if !snapshot.tenantComments.isEmpty {
            writer.draw(ReportStyle.text("TENANT COMMENTS", font: ReportStyle.sans(7.5, .bold), color: ReportStyle.muted), x: writer.left, y: writer.y, width: 200)
            writer.y += 13
            writer.paragraph(ReportStyle.text(snapshot.tenantComments, font: ReportStyle.sans(9.5), lineSpacing: 2), spacingAfter: 14)
        }

        if snapshot.signatures.isEmpty {
            writer.paragraph(ReportStyle.text("This report has not been signed.", font: ReportStyle.sans(9.5, .semibold), color: ReportStyle.muted), spacingAfter: 10)
            // Blank signature lines for printing
            for label in ["Tenant", "Landlord / agent"] {
                writer.ensureSpace(60)
                writer.y += 34
                writer.line(from: CGPoint(x: writer.left, y: writer.y), to: CGPoint(x: writer.left + writer.contentWidth * 0.55, y: writer.y), color: ReportStyle.ink)
                writer.line(from: CGPoint(x: writer.left + writer.contentWidth * 0.65, y: writer.y), to: CGPoint(x: writer.left + writer.contentWidth, y: writer.y), color: ReportStyle.ink)
                writer.draw(ReportStyle.text("\(label) signature", font: ReportStyle.sans(7.5), color: ReportStyle.muted), x: writer.left, y: writer.y + 3, width: 200)
                writer.draw(ReportStyle.text("Date", font: ReportStyle.sans(7.5), color: ReportStyle.muted), x: writer.left + writer.contentWidth * 0.65, y: writer.y + 3, width: 100)
                writer.y += 16
            }
            return
        }

        for signature in snapshot.signatures {
            let statement = ReportStyle.text(signature.statement, font: ReportStyle.sans(8.5), color: ReportStyle.muted, lineSpacing: 2)
            let statementHeight = writer.measure(statement, width: writer.contentWidth - 24)
            let blockHeight = statementHeight + 110
            writer.ensureSpace(blockHeight)
            let top = writer.y
            writer.stroke(CGRect(x: writer.left, y: top, width: writer.contentWidth, height: blockHeight - 10), color: ReportStyle.rule, width: 0.75, radius: 6)
            writer.draw(ReportStyle.text(signature.role.label.uppercased(), font: ReportStyle.sans(7.5, .bold), color: ReportStyle.gold), x: writer.left + 12, y: top + 12, width: 200)
            writer.draw(statement, x: writer.left + 12, y: top + 26, width: writer.contentWidth - 24)
            let signatureY = top + 32 + statementHeight
            if writer.isDrawing, let image = PhotoStore.shared.image(signature.imageFilename) {
                writer.imageFit(image, in: CGRect(x: writer.left + 12, y: signatureY, width: 170, height: 46))
            }
            writer.line(from: CGPoint(x: writer.left + 12, y: signatureY + 50), to: CGPoint(x: writer.left + 230, y: signatureY + 50), color: ReportStyle.ink)
            writer.draw(ReportStyle.text(signature.name, font: ReportStyle.sans(9.5, .semibold)), x: writer.left + 12, y: signatureY + 54, width: 220)
            writer.draw(ReportStyle.text("Signed \(signature.signedAt.formatted(date: .long, time: .shortened))", font: ReportStyle.sans(8.5), color: ReportStyle.muted, alignment: .right), x: writer.left + writer.contentWidth - 260, y: signatureY + 54, width: 248)
            writer.y = top + blockHeight
        }
    }

    // MARK: Evidence appendix

    private func evidenceAppendix() {
        guard !snapshot.allPhotos.isEmpty else { return }
        writer.newPage()
        heading("Evidence appendix", subtitle: "Every photo in this report with its capture time, location and SHA-256 fingerprint.")
        let manifest = ReportStyle.text("Manifest fingerprint: \(snapshot.manifestHash)", font: ReportStyle.mono(7), color: ReportStyle.muted)
        writer.paragraph(manifest, spacingAfter: 10)

        let columns: [(String, CGFloat)] = [("Ref", 0.07), ("Captured", 0.2), ("Subject", 0.25), ("Location", 0.16), ("SHA-256", 0.32)]
        tableHeader(columns)
        for photo in snapshot.allPhotos {
            var location = "—"
            if let lat = photo.latitude, let lon = photo.longitude {
                location = String(format: "%.5f,\n%.5f", lat, lon)
            }
            var captured = photo.capturedAt.formatted(date: .numeric, time: .standard)
            if photo.isImported { captured += "\nimported" }
            tableRow(columns, values: [
                ReportStyle.text(photo.ref, font: ReportStyle.sans(7.5, .bold), color: ReportStyle.evergreen),
                ReportStyle.text(captured, font: ReportStyle.sans(7.5)),
                ReportStyle.text(photo.label, font: ReportStyle.sans(7.5)),
                ReportStyle.text(location, font: ReportStyle.mono(6.5)),
                ReportStyle.text(photo.sha256, font: ReportStyle.mono(6))
            ], header: columns)
        }
    }
}
