import SwiftUI
import SwiftData
import PhotosUI

struct RoomView: View {
    @Bindable var room: Room

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store
    @AppStorage(PrefKey.aiConsent) private var aiConsent = false

    @State private var showingCamera = false
    @State private var libraryItems: [PhotosPickerItem] = []
    @State private var isWorking = false
    @State private var aiError: String?
    @State private var showingConsent = false
    @State private var showingPaywall = false
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var confirmDelete = false
    @State private var viewerPhoto: EvidencePhoto?
    @State private var aiResultMessage: String?

    private var locked: Bool { room.inspection?.isLocked ?? false }
    private var isFollowUp: Bool { room.inspection?.kind != .checkIn && room.baselineRoom != nil }
    private var region: Region { room.inspection?.region ?? .unitedKingdom }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if isFollowUp, let baselineRoom = room.baselineRoom {
                    baselineStrip(baselineRoom)
                }
                photosSection
                if !locked { aiCard }
                if !room.summary.isEmpty { summaryCard }
                itemsSection
                notesSection
                if !locked {
                    Toggle(isOn: $room.isMarkedComplete) {
                        Label("Room complete", systemImage: "checkmark.circle")
                            .font(.headline)
                    }
                    .tint(Theme.accent)
                    .card()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !locked {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { newName = room.name; showingRename = true } label: { Label("Rename room", systemImage: "pencil") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete room", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CaptureView(title: room.name, overlayFilename: room.baselineRoom?.allPhotos.first?.filename) { capture in
                if let photo = EvidenceCapture.store(capture, in: context) {
                    photo.room = room
                }
            }
        }
        .sheet(item: $viewerPhoto) { photo in
            PhotoViewer(photo: photo, canDelete: !locked) {
                viewerPhoto = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    InspectionFactory.delete(photo, in: context)
                }
            }
        }
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet {
                aiConsent = true
                showingConsent = false
                runAI()
            }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView(reason: .ai) }
        .alert("Rename room", isPresented: $showingRename) {
            TextField("Room name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { room.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Add item", isPresented: $showingAddItem) {
            TextField("e.g. Bookshelf", text: $newItemName)
            Button("Add") {
                let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { _ = InspectionFactory.addItem(named: trimmed, to: room, in: context) }
                newItemName = ""
            }
            Button("Cancel", role: .cancel) { newItemName = "" }
        }
        .alert("AI couldn't finish", isPresented: Binding(get: { aiError != nil }, set: { if !$0 { aiError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiError ?? "")
        }
        .confirmationDialog("Delete \(room.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete room and its photos", role: .destructive) {
                let target = room
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    for photo in target.allPhotos { PhotoStore.shared.delete(photo.filename) }
                    context.delete(target)
                }
            }
        }
        .onChange(of: libraryItems) { _, items in
            importPhotos(items)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: 54, height: 54)
                Image(systemName: room.kind.symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(room.name).font(.display(26, weight: .bold))
                Text("\(room.items.count) items · \(room.allPhotos.count) photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private func baselineStrip(_ baselineRoom: Room) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("At \(region.shortName(for: .checkIn).lowercased())")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if baselineRoom.allPhotos.isEmpty {
                Text("No photos were taken of this room at \(region.shortName(for: .checkIn).lowercased()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(baselineRoom.allPhotos) { photo in
                            Button { viewerPhoto = photo } label: {
                                PhotoThumbnail(filename: photo.filename, size: 84)
                                    .overlay(alignment: .bottomLeading) {
                                        Text(photo.capturedAt.formatted(date: .numeric, time: .omitted))
                                            .font(.system(size: 9, weight: .semibold))
                                            .padding(4)
                                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                                            .foregroundStyle(.white)
                                            .padding(4)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .card(padding: 14)
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Room photos", subtitle: "Stand in each corner and photograph the whole room, then close-ups of anything worth noting.")
            let photos = room.sortedPhotos
            if !photos.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(photos) { photo in
                        Button { viewerPhoto = photo } label: {
                            FillPhoto(filename: photo.filename)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !locked {
                HStack(spacing: 10) {
                    Button { showingCamera = true } label: {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    .buttonStyle(.primary)
                    PhotosPicker(selection: $libraryItems, maxSelectionCount: 20, matching: .images) {
                        Label("Library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    // MARK: AI

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Theme.gold)
                    .symbolEffect(.pulse, isActive: isWorking)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isFollowUp ? "Compare with AI" : "Describe with AI")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(aiSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            if let aiResultMessage {
                Label(aiResultMessage, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.gold)
            }
            Button(action: startAI) {
                HStack {
                    if isWorking {
                        ProgressView().tint(.black)
                        Text(isFollowUp ? "Comparing photos…" : "Writing descriptions…")
                    } else {
                        Text(aiButtonTitle)
                    }
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isWorking || room.allPhotos.isEmpty)
            .opacity(room.allPhotos.isEmpty ? 0.5 : 1)
        }
        .padding(16)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var aiSubtitle: String {
        if room.allPhotos.isEmpty { return "Take photos first. AI reads them and fills in every item." }
        if isFollowUp { return "Spots changes since \(region.shortName(for: .checkIn).lowercased()) and separates fair wear and tear from damage." }
        return "Writes clerk-style descriptions and ratings for every item. You review and edit."
    }

    private var aiButtonTitle: String {
        let done = isFollowUp ? room.aiComparedAt != nil : room.aiGeneratedAt != nil
        let base = done ? (isFollowUp ? "Compare again" : "Rewrite descriptions") : (isFollowUp ? "Compare room" : "Describe room")
        if !store.isPro { return "\(base) · \(store.freeAIRemaining) free left" }
        return base
    }

    private func startAI() {
        guard store.canUseAI else {
            showingPaywall = true
            return
        }
        guard aiConsent else {
            showingConsent = true
            return
        }
        runAI()
    }

    private func runAI() {
        isWorking = true
        aiResultMessage = nil
        let roomName = room.name
        let kind = room.kind
        let furnishing = room.inspection?.property?.furnishing ?? .unfurnished
        let region = self.region
        let currentFiles = room.allPhotos.prefix(8).map(\.filename)
        let baselineFiles = (room.baselineRoom?.allPhotos ?? []).prefix(5).map(\.filename)
        let itemNames = room.sortedItems.map(\.name)
        let compareItems = room.sortedItems.map {
            AIService.CompareItem(name: $0.name, baselineDescription: $0.baselineDescription, baselineCondition: $0.baselineCondition.label, baselineCleanliness: $0.baselineCleanliness.label)
        }
        let followUp = isFollowUp

        Task {
            do {
                let current = await loadImages(Array(currentFiles))
                if followUp {
                    let baseline = await loadImages(Array(baselineFiles))
                    let result = try await AIService.shared.compareRoom(name: roomName, region: region, items: compareItems, baselinePhotos: baseline, currentPhotos: current)
                    applyComparison(result)
                } else {
                    let result = try await AIService.shared.describeRoom(name: roomName, kind: kind, furnishing: furnishing, region: region, itemNames: itemNames, photos: current)
                    applyDescription(result)
                }
                store.recordAIUse()
                Haptics.success()
            } catch {
                aiError = error.localizedDescription
                Haptics.warning()
            }
            isWorking = false
        }
    }

    private func loadImages(_ filenames: [String]) async -> [UIImage] {
        await Task.detached(priority: .userInitiated) {
            filenames.compactMap { PhotoStore.shared.image($0) }
        }.value
    }

    private func matchItem(_ name: String) -> RoomItem? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        if let exact = room.items.first(where: { $0.name.lowercased() == key }) { return exact }
        return room.items.first(where: { $0.name.lowercased().contains(key) || key.contains($0.name.lowercased()) })
    }

    private func applyDescription(_ result: AIService.DescribeResponse) {
        var updated = 0
        var added = 0
        for described in result.items {
            let item: RoomItem
            if let existing = matchItem(described.name) {
                item = existing
                updated += 1
            } else {
                item = InspectionFactory.addItem(named: described.name, to: room, in: context)
                added += 1
            }
            item.itemDescription = described.description
            item.condition = Condition(aiValue: described.condition)
            item.cleanliness = Cleanliness(aiValue: described.cleanliness)
            item.aiGenerated = true
        }
        room.summary = result.summary
        room.aiGeneratedAt = .now
        try? context.save()
        aiResultMessage = added > 0 ? "Described \(updated) items and found \(added) more. Review each one." : "Described \(updated) items. Review each one."
    }

    private func applyComparison(_ result: AIService.CompareResponse) {
        var flagged = 0
        for compared in result.items {
            guard let item = matchItem(compared.name) else { continue }
            let change = ChangeKind(aiValue: compared.change)
            item.change = change
            item.changeNote = compared.note
            if let description = compared.description, !description.isEmpty { item.itemDescription = description }
            if let condition = compared.condition { item.condition = Condition(aiValue: condition) }
            if let cleanliness = compared.cleanliness { item.cleanliness = Cleanliness(aiValue: cleanliness) }
            if change.isChargeable {
                flagged += 1
                if item.deductionAmount == 0, let suggested = compared.suggestedDeduction, suggested > 0 {
                    item.deductionAmount = suggested.rounded()
                }
            } else {
                item.deductionAmount = 0
            }
            item.aiGenerated = true
        }
        room.summary = result.summary
        room.aiComparedAt = .now
        try? context.save()
        aiResultMessage = flagged == 0 ? "No chargeable changes found. Check each item yourself." : "\(flagged) item\(flagged == 1 ? "" : "s") flagged. Review before claiming."
    }

    // MARK: Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Room summary")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField("Summary", text: $room.summary, axis: .vertical)
                .font(.callout)
                .disabled(locked)
        }
        .card()
    }

    // MARK: Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("Items")
                if !locked {
                    Button { showingAddItem = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add item")
                }
            }
            VStack(spacing: 0) {
                ForEach(room.sortedItems) { item in
                    NavigationLink {
                        ItemEditorView(item: item)
                    } label: {
                        ItemRow(item: item, showChange: isFollowUp)
                    }
                    .buttonStyle(.plain)
                    if item.id != room.sortedItems.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.5))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Notes")
            TextField("Smells, damp, pests, anything else", text: $room.notes, axis: .vertical)
                .lineLimit(2...6)
                .disabled(locked)
                .card()
        }
    }

    // MARK: Import

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for pickerItem in items {
                if let data = try? await pickerItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    let capture = CapturedPhoto(image: image, capturedAt: .now, location: nil, isImported: true)
                    if let photo = EvidenceCapture.store(capture, in: context) {
                        photo.room = room
                        photo.caption = "Imported from photo library"
                    }
                }
            }
            libraryItems = []
            try? context.save()
        }
    }
}

struct ItemRow: View {
    let item: RoomItem
    var showChange = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.name).font(.headline)
                    if item.aiGenerated {
                        Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.gold)
                    }
                }
                if item.itemDescription.isEmpty {
                    Text("Not described yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(item.itemDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if showChange && item.change != .unassessed {
                        ChangePill(change: item.change)
                    } else {
                        ConditionPill(condition: item.condition)
                    }
                    if !item.photos.isEmpty {
                        Pill(text: "\(item.photos.count)", color: .secondary, symbol: "camera.fill")
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

struct PhotoViewer: View {
    let photo: EvidencePhoto
    let canDelete: Bool
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = PhotoStore.shared.image(photo.filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(photo.capturedAt.formatted(date: .long, time: .standard), systemImage: "clock")
                    if let lat = photo.latitude, let lon = photo.longitude {
                        Label(String(format: "%.5f, %.5f", lat, lon), systemImage: "location.fill")
                    }
                    Label("SHA-256 \(photo.shortHash)…", systemImage: "number")
                        .font(.footnote.monospaced())
                    if photo.isImported {
                        Label("Imported from library, not captured in Handover", systemImage: "photo")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Captured in Handover", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                Spacer()
            }
            .padding()
            .background(Theme.background)
            .navigationTitle("Evidence photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if canDelete {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                    }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete photo", role: .destructive, action: onDelete)
            }
        }
    }
}
