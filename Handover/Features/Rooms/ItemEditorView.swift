import SwiftUI
import SwiftData
import PhotosUI

struct ItemEditorView: View {
    @Bindable var item: RoomItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingCamera = false
    @State private var libraryItems: [PhotosPickerItem] = []
    @State private var viewerPhoto: EvidencePhoto?
    @State private var confirmDelete = false

    private var locked: Bool { item.room?.inspection?.isLocked ?? false }
    private var region: Region { item.room?.inspection?.region ?? .unitedKingdom }
    private var isFollowUp: Bool { item.hasBaseline && item.room?.inspection?.kind != .checkIn }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TextField("Item name", text: $item.name)
                    .font(.display(26, weight: .bold))
                    .disabled(locked)
                    .padding(.top, 8)

                if isFollowUp { baselinePanel }

                descriptionSection
                conditionSection
                cleanlinessSection
                if isFollowUp { changeSection }
                photosSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle(item.room?.name ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !locked {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete item")
                }
            }
        }
        .confirmationDialog("Delete \(item.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete item", role: .destructive) {
                let target = item
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    for photo in target.photos { PhotoStore.shared.delete(photo.filename) }
                    context.delete(target)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CaptureView(title: item.name, overlayFilename: item.baselineItem?.sortedPhotos.first?.filename) { capture in
                if let photo = EvidenceCapture.store(capture, in: context) {
                    photo.item = item
                }
            }
        }
        .sheet(item: $viewerPhoto) { photo in
            PhotoViewer(photo: photo, canDelete: !locked && photo.item?.id == item.id) {
                viewerPhoto = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    InspectionFactory.delete(photo, in: context)
                }
            }
        }
        .onChange(of: libraryItems) { _, items in importPhotos(items) }
    }

    // MARK: Baseline

    private var baselinePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("At \(region.shortName(for: .checkIn).lowercased())")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(item.baselineDescription.isEmpty ? "No description recorded." : item.baselineDescription)
                .font(.callout)
            HStack(spacing: 6) {
                ConditionPill(condition: item.baselineCondition)
                if item.baselineCleanliness != .notApplicable {
                    Pill(text: item.baselineCleanliness.label, color: .secondary)
                }
            }
            if let baselinePhotos = item.baselineItem?.sortedPhotos, !baselinePhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(baselinePhotos) { photo in
                            Button { viewerPhoto = photo } label: { PhotoThumbnail(filename: photo.filename, size: 72) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isFollowUp ? "Condition now" : "Description")
                    .font(.headline)
                if item.aiGenerated {
                    Pill(text: "AI draft", color: Theme.gold, symbol: "sparkles")
                }
            }
            TextField("Colour, material, size and any marks. For example: \"Beige fitted carpet, light wear at threshold, 4cm stain by window.\"", text: $item.itemDescription, axis: .vertical)
                .lineLimit(3...10)
                .disabled(locked)
                .card()
        }
    }

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Condition").font(.headline)
            ChipGrid {
                ForEach(Condition.allCases) { condition in
                    Chip(title: condition.label, isSelected: item.condition == condition, color: condition.color) {
                        item.condition = condition
                    }
                }
            }
            .disabled(locked)
            Text(item.condition.definition)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var cleanlinessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cleanliness").font(.headline)
            ChipGrid {
                ForEach(Cleanliness.allCases) { value in
                    Chip(title: value.shortLabel, isSelected: item.cleanliness == value, color: Theme.accent) {
                        item.cleanliness = value
                    }
                }
            }
            .disabled(locked)
        }
    }

    // MARK: Change

    private var changeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Change since \(region.shortName(for: .checkIn).lowercased())").font(.headline)
            ChipGrid {
                ForEach(ChangeKind.allCases.filter { $0 != .unassessed }) { change in
                    Chip(title: change.label, isSelected: item.change == change, color: change.color) {
                        item.change = change
                        if !change.isChargeable { item.deductionAmount = 0 }
                    }
                }
            }
            .disabled(locked)

            TextField("What changed and why it's beyond fair wear and tear", text: $item.changeNote, axis: .vertical)
                .lineLimit(2...6)
                .disabled(locked)
                .card()

            if item.change.isChargeable {
                HStack {
                    Text("Proposed deduction").font(.subheadline.weight(.semibold))
                    Spacer()
                    TextField("0", value: $item.deductionAmount, format: .currency(code: region.currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.headline.monospacedDigit())
                        .disabled(locked)
                }
                .card()
                Text("Charge the actual cost of putting it right, less an allowance for age and normal use. AI suggestions are a starting point only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Close-up photos").font(.headline)
            let photos = item.sortedPhotos
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
                    Button { showingCamera = true } label: { Label("Camera", systemImage: "camera.fill") }
                        .buttonStyle(.primary)
                    PhotosPicker(selection: $libraryItems, maxSelectionCount: 10, matching: .images) {
                        Label("Library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for pickerItem in items {
                if let data = try? await pickerItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    let capture = CapturedPhoto(image: image, capturedAt: .now, location: nil, isImported: true)
                    if let photo = EvidenceCapture.store(capture, in: context) {
                        photo.item = item
                        photo.caption = "Imported from photo library"
                    }
                }
            }
            libraryItems = []
            try? context.save()
        }
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    let isSelected: Bool
    var color: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    Capsule().fill(isSelected ? color : Theme.card)
                }
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

/// Wraps chips onto as many lines as needed.
struct ChipGrid: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
