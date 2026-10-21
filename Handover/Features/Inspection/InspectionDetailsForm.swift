import SwiftUI
import SwiftData

struct InspectionDetailsForm: View {
    @Bindable var inspection: Inspection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var hasStartDate = true
    @State private var hasEndDate = false

    private var region: Region { inspection.region }

    var body: some View {
        NavigationStack {
            Form {
                Section("People") {
                    TextField("Tenant name(s)", text: $inspection.tenantNames)
                        .textContentType(.name)
                    TextField("Tenant email", text: $inspection.tenantEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Landlord or company", text: $inspection.landlordName)
                    TextField("Inspected by", text: $inspection.inspectorName)
                }

                Section("Tenancy") {
                    Toggle("Tenancy start date", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("Starts", selection: Binding(
                            get: { inspection.tenancyStartDate ?? .now },
                            set: { inspection.tenancyStartDate = $0 }
                        ), displayedComponents: .date)
                    }
                    if inspection.kind != .checkIn {
                        Toggle("Tenancy end date", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Ends", selection: Binding(
                                get: { inspection.tenancyEndDate ?? .now },
                                set: { inspection.tenancyEndDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                }

                Section(region.depositTerm.capitalized) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0", value: $inspection.depositAmount, format: .currency(code: region.currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Held with", selection: $inspection.depositScheme) {
                        Text("Not set").tag("")
                        ForEach(region.depositSchemes, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Reference number", text: $inspection.depositReference)
                }

                Section("General notes") {
                    TextField("Anything the report should mention", text: $inspection.generalNotes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    TextField("Tenant's comments", text: $inspection.tenantComments, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Tenant comments")
                } footer: {
                    Text("Anything the tenant disagrees with or wants noted. It's printed above the signatures.")
                }
            }
            .navigationTitle("Report details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if !hasStartDate { inspection.tenancyStartDate = nil }
                        if !hasEndDate { inspection.tenancyEndDate = nil }
                        if hasStartDate && inspection.tenancyStartDate == nil { inspection.tenancyStartDate = .now }
                        if hasEndDate && inspection.tenancyEndDate == nil { inspection.tenancyEndDate = .now }
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                hasStartDate = inspection.tenancyStartDate != nil
                hasEndDate = inspection.tenancyEndDate != nil
            }
        }
    }
}

struct MetersKeysView: View {
    @Bindable var inspection: Inspection
    @Environment(\.modelContext) private var context
    @State private var cameraTarget: MeterReading?

    var body: some View {
        Form {
            ForEach(inspection.sortedMeters) { meter in
                MeterSection(meter: meter, locked: inspection.isLocked) {
                    cameraTarget = meter
                }
            }
            if !inspection.isLocked {
                Section {
                    Menu {
                        ForEach(MeterType.allCases) { type in
                            Button(type.label) {
                                let meter = MeterReading(type: type, order: (inspection.meters.map(\.order).max() ?? -1) + 1)
                                context.insert(meter)
                                meter.inspection = inspection
                            }
                        }
                    } label: {
                        Label("Add meter", systemImage: "plus")
                    }
                }
            }

            Section("Keys & access") {
                ForEach(inspection.sortedKeys) { key in
                    KeyRow(key: key, locked: inspection.isLocked)
                }
                .onDelete { offsets in
                    guard !inspection.isLocked else { return }
                    let keys = inspection.sortedKeys
                    for index in offsets { context.delete(keys[index]) }
                }
                if !inspection.isLocked {
                    Button {
                        let key = KeyRecord(label: "", quantity: 1, order: (inspection.keys.map(\.order).max() ?? -1) + 1)
                        context.insert(key)
                        key.inspection = inspection
                    } label: {
                        Label("Add key or fob", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle("Meters & keys")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $cameraTarget) { meter in
            CaptureView(title: "\(meter.type.label) meter", overlayFilename: nil) { capture in
                if let photo = EvidenceCapture.store(capture, in: context) {
                    photo.meter = meter
                }
            }
        }
    }
}

private struct MeterSection: View {
    @Bindable var meter: MeterReading
    let locked: Bool
    let onCamera: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            HStack {
                Text("Reading")
                Spacer()
                TextField("00000", text: $meter.reading)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
            }
            TextField("Meter serial number", text: $meter.serialNumber)
            TextField("Location (e.g. under stairs)", text: $meter.location)
            HStack(spacing: 10) {
                ForEach(meter.photos.sorted { $0.capturedAt < $1.capturedAt }) { photo in
                    PhotoThumbnail(filename: photo.filename, size: 56)
                        .contextMenu {
                            if !locked {
                                Button(role: .destructive) {
                                    InspectionFactory.delete(photo, in: context)
                                } label: { Label("Delete photo", systemImage: "trash") }
                            }
                        }
                }
                if !locked {
                    Button(action: onCamera) {
                        Label("Photo", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Label(meter.type.label, systemImage: meter.type.symbol)
        }
        .disabled(locked)
    }
}

private struct KeyRow: View {
    @Bindable var key: KeyRecord
    let locked: Bool

    var body: some View {
        HStack {
            TextField("Description", text: $key.label)
            Stepper("\(key.quantity)", value: $key.quantity, in: 0...50)
                .fixedSize()
        }
        .disabled(locked)
    }
}

struct DeductionsView: View {
    @Bindable var inspection: Inspection
    private var region: Region { inspection.region }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("\(region.depositTerm.capitalized) held")
                    Spacer()
                    Text(inspection.depositAmount.currency(region)).monospacedDigit()
                }
                HStack {
                    Text("Proposed deductions")
                    Spacer()
                    Text(inspection.totalDeductions.currency(region)).monospacedDigit().foregroundStyle(ChangeKind.damage.color)
                }
                HStack {
                    Text("Balance to return").fontWeight(.semibold)
                    Spacer()
                    Text(max(0, inspection.depositAmount - inspection.totalDeductions).currency(region)).monospacedDigit().fontWeight(.semibold)
                }
            } footer: {
                Text("Deductions should reflect the actual loss, allowing for fair wear and tear and the age of each item. Adjudicators expect evidence for every charge.")
            }

            Section("Items") {
                if inspection.chargeableItems.isEmpty {
                    Text("No items are marked as cleaning, damage or missing yet. Mark them in each room to build your claim.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(inspection.chargeableItems) { entry in
                    NavigationLink {
                        ItemEditorView(item: entry.item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(entry.room.name) · \(entry.item.name)").font(.headline)
                                Spacer()
                                Text(entry.item.deductionAmount.currency(region)).monospacedDigit()
                            }
                            ChangePill(change: entry.item.change)
                            if !entry.item.changeNote.isEmpty {
                                Text(entry.item.changeNote).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("\(region.depositTerm.capitalized) claim")
        .navigationBarTitleDisplayMode(.inline)
    }
}
