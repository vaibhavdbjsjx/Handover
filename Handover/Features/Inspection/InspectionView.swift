import SwiftUI
import SwiftData

struct InspectionView: View {
    @Bindable var inspection: Inspection

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var showingDetails = false
    @State private var showingReport = false
    @State private var showingSignature = false
    @State private var showingAddRoom = false
    @State private var confirmReopen = false
    @State private var confirmDelete = false
    @State private var confirmFinalise = false

    private var region: Region { inspection.region }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerCard
                if inspection.isLocked { lockedBanner }
                detailsCard
                if inspection.kind == .checkOut { depositCard }
                roomsSection
                metersSection
                signaturesSection
                Button {
                    showingReport = true
                } label: {
                    Label(inspection.isLocked ? "View & share report" : "Preview report", systemImage: "doc.richtext.fill")
                }
                .buttonStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle(region.shortName(for: inspection.kind))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingDetails = true } label: { Label("Edit details", systemImage: "pencil") }
                        .disabled(inspection.isLocked)
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete report", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingDetails) { InspectionDetailsForm(inspection: inspection) }
        .sheet(isPresented: $showingSignature) { SignatureCaptureView(inspection: inspection) }
        .sheet(isPresented: $showingAddRoom) { AddRoomSheet(inspection: inspection) }
        .fullScreenCover(isPresented: $showingReport) { ReportPreviewView(inspection: inspection) }
        .confirmationDialog("Reopen this report?", isPresented: $confirmReopen, titleVisibility: .visible) {
            Button("Reopen and remove signatures", role: .destructive, action: reopen)
        } message: {
            Text("Signatures confirm the report as it was signed. Editing it means everyone needs to sign again.")
        }
        .confirmationDialog("Delete this report?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete report and photos", role: .destructive) {
                let target = inspection
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    InspectionFactory.delete(target, in: context)
                    try? context.save()
                }
            }
        } message: {
            Text("This can't be undone. Export the PDF first if you need a copy.")
        }
        .alert("Finalise and lock the report?", isPresented: $confirmFinalise) {
            Button("Finalise") { finalise() }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("The report will be locked so it stays exactly as it was signed. You can still view and share it.")
        }
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(inspection.title)
                        .font(.display(24, weight: .bold))
                        .foregroundStyle(.white)
                    Text(inspection.property?.displayName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    DatePicker("Date", selection: $inspection.date, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.colorScheme, .dark)
                        .disabled(inspection.isLocked)
                }
                Spacer()
                ZStack {
                    ProgressRing(progress: inspection.progress, lineWidth: 6, color: Theme.gold)
                    Text("\(Int(inspection.progress * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
            }
            HStack(spacing: 18) {
                headerStat("\(inspection.completedRoomCount)/\(inspection.rooms.count)", "Rooms done")
                headerStat("\(inspection.itemCount)", "Items")
                headerStat("\(inspection.photoCount)", "Photos")
                Spacer()
                Pill(text: inspection.status.label, color: inspection.isLocked ? Theme.gold : .white, symbol: inspection.isLocked ? "lock.fill" : "pencil")
            }
        }
        .padding(18)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.radius + 4, style: .continuous))
        .padding(.top, 8)
    }

    private func headerStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var lockedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Signed and locked").font(.headline)
                if let signedAt = inspection.signedAt {
                    Text("Finalised \(signedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Reopen") { confirmReopen = true }
                .font(.subheadline.weight(.semibold))
        }
        .card()
    }

    // MARK: Details

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("Tenancy")
                if !inspection.isLocked {
                    Button("Edit") { showingDetails = true }
                        .font(.subheadline.weight(.semibold))
                }
            }
            VStack(spacing: 0) {
                detailRow("Tenant", inspection.tenantNames.isEmpty ? "Add tenant names" : inspection.tenantNames, isPlaceholder: inspection.tenantNames.isEmpty)
                Divider()
                detailRow("Landlord", inspection.landlordName.isEmpty ? "Add landlord" : inspection.landlordName, isPlaceholder: inspection.landlordName.isEmpty)
                if let start = inspection.tenancyStartDate {
                    Divider()
                    detailRow("Tenancy start", start.formatted(date: .abbreviated, time: .omitted))
                }
                if inspection.depositAmount > 0 {
                    Divider()
                    detailRow(region.depositTerm.capitalized, inspection.depositAmount.currency(region))
                }
            }
            .card(padding: 14)
            .onTapGesture { if !inspection.isLocked { showingDetails = true } }
        }
    }

    private func detailRow(_ label: String, _ value: String, isPlaceholder: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(isPlaceholder ? Theme.accent : .primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 9)
    }

    // MARK: Deposit

    private var depositCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("\(region.depositTerm.capitalized) claim", subtitle: "Built from items marked as cleaning, damage or missing.")
            NavigationLink {
                DeductionsView(inspection: inspection)
            } label: {
                HStack(spacing: 12) {
                    StatTile(value: inspection.depositAmount.currency(region), label: "Held")
                    StatTile(value: inspection.totalDeductions.currency(region), label: "Proposed deductions")
                    StatTile(value: max(0, inspection.depositAmount - inspection.totalDeductions).currency(region), label: "To return")
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("Rooms", subtitle: inspection.kind == .checkIn ? "Photograph each room, then let AI write the descriptions." : "Retake photos and compare each room with the \(region.shortName(for: .checkIn).lowercased()).")
                if !inspection.isLocked {
                    Button { showingAddRoom = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add room")
                }
            }
            ForEach(inspection.sortedRooms) { room in
                NavigationLink {
                    RoomView(room: room)
                } label: {
                    RoomRow(room: room)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Meters and keys

    private var metersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Meters & keys")
            NavigationLink {
                MetersKeysView(inspection: inspection)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(inspection.meters.filter { !$0.reading.isEmpty }.count) of \(inspection.meters.count) meter readings")
                            .font(.headline)
                        Text("\(inspection.keys.reduce(0) { $0 + $1.quantity }) keys recorded")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Signatures

    private var signaturesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Signatures", subtitle: "Sign together at the property to make the report hard to dispute.")
            VStack(spacing: 0) {
                if inspection.signatures.isEmpty {
                    Text("No signatures yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                ForEach(inspection.sortedSignatures) { signature in
                    HStack(spacing: 12) {
                        if let image = PhotoStore.shared.image(signature.imageFilename) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 40)
                                .padding(4)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(signature.name).font(.headline)
                            Text("\(signature.role.label) · \(signature.signedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !inspection.isLocked {
                            Button(role: .destructive) {
                                PhotoStore.shared.delete(signature.imageFilename)
                                context.delete(signature)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .card(padding: 14)

            if !inspection.isLocked {
                HStack(spacing: 10) {
                    Button { showingSignature = true } label: {
                        Label("Add signature", systemImage: "signature")
                    }
                    .buttonStyle(.secondary)
                    Button { confirmFinalise = true } label: {
                        Label("Finalise", systemImage: "lock.fill")
                    }
                    .buttonStyle(.secondary)
                    .disabled(inspection.signatures.isEmpty)
                }
            }
        }
    }

    private func finalise() {
        inspection.status = .signed
        inspection.signedAt = .now
        for room in inspection.rooms { room.isMarkedComplete = true }
        try? context.save()
        Haptics.success()
    }

    private func reopen() {
        for signature in inspection.signatures {
            PhotoStore.shared.delete(signature.imageFilename)
            context.delete(signature)
        }
        inspection.status = .draft
        inspection.signedAt = nil
        try? context.save()
    }
}

struct RoomRow: View {
    let room: Room

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                if let first = room.allPhotos.first {
                    PhotoThumbnail(filename: first.filename, size: 56)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.1))
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: room.kind.symbol).font(.title3).foregroundStyle(Theme.accent))
                }
                if room.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white, Theme.accent)
                        .offset(x: 5, y: 5)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(room.name).font(.headline)
                HStack(spacing: 6) {
                    Text("\(room.items.count) items · \(room.allPhotos.count) photos")
                    if room.aiGeneratedAt != nil || room.aiComparedAt != nil {
                        Image(systemName: "sparkles").foregroundStyle(Theme.gold)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if room.inspection?.kind != .checkIn && room.issueCount > 0 {
                Pill(text: "\(room.issueCount)", color: ChangeKind.damage.color, symbol: "exclamationmark.triangle.fill")
            }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .card(padding: 12)
    }
}

struct AddRoomSheet: View {
    let inspection: Inspection
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: RoomKind = .bedroom

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Room name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(RoomKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                } footer: {
                    Text("We'll add the usual items for a \(kind.label.lowercased()). You can change them afterwards.")
                }
            }
            .navigationTitle("Add room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? kind.label : name
                        _ = InspectionFactory.addRoom(named: finalName, kind: kind, to: inspection, in: context)
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
