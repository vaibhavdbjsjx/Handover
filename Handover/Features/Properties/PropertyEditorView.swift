import SwiftUI
import SwiftData
import PhotosUI

struct PropertyEditorView: View {
    let property: Property?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postcode = ""
    @State private var region = Preferences.region
    @State private var type = PropertyType.flat
    @State private var furnishing = Furnishing.unfurnished
    @State private var bedrooms = 2
    @State private var bathrooms = 1
    @State private var notes = ""
    @State private var coverItem: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var removeCover = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    coverPicker
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Address") {
                    TextField("Nickname (optional)", text: $nickname)
                    TextField("Address line 1", text: $addressLine1)
                        .textContentType(.streetAddressLine1)
                    TextField("Address line 2", text: $addressLine2)
                        .textContentType(.streetAddressLine2)
                    TextField(region.cityLabel, text: $city)
                        .textContentType(.addressCity)
                    if let stateLabel = region.stateLabel {
                        TextField(stateLabel, text: $state)
                            .textContentType(.addressState)
                    }
                    TextField(region.postcodeLabel, text: $postcode)
                        .textContentType(.postalCode)
                        .textInputAutocapitalization(.characters)
                    Picker("Country", selection: $region) {
                        ForEach(Region.allCases) { Text("\($0.flag)  \($0.displayName)").tag($0) }
                    }
                }

                Section("Property") {
                    Picker("Type", selection: $type) {
                        ForEach(PropertyType.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Furnishing", selection: $furnishing) {
                        ForEach(Furnishing.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Bedrooms: \(bedrooms)", value: $bedrooms, in: 0...12)
                    Stepper("Bathrooms: \(bathrooms)", value: $bathrooms, in: 1...8)
                }

                Section("Notes") {
                    TextField("Access, parking, alarm codes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if property != nil {
                    Section {
                        Text("Changing bedrooms or bathrooms here won't change rooms in reports you've already started.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(property == nil ? "New property" : "Edit property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(addressLine1.trimmingCharacters(in: .whitespaces).isEmpty && nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .onChange(of: coverItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        coverImage = image
                        removeCover = false
                    }
                }
            }
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $coverItem, matching: .images) {
            ZStack {
                if let coverImage {
                    Image(uiImage: coverImage).resizable().scaledToFill()
                } else if let existing = property?.coverPhotoFilename, !removeCover {
                    FillPhoto(filename: existing, aspect: 2.2)
                } else {
                    Theme.heroGradient
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill").font(.title2)
                        Text("Add a cover photo").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func load() {
        guard let property else { return }
        nickname = property.nickname
        addressLine1 = property.addressLine1
        addressLine2 = property.addressLine2
        city = property.city
        state = property.state
        postcode = property.postcode
        region = property.region
        type = property.type
        furnishing = property.furnishing
        bedrooms = property.bedrooms
        bathrooms = property.bathrooms
        notes = property.notes
    }

    private func save() {
        let target: Property
        if let property {
            target = property
        } else {
            target = Property(region: region)
            context.insert(target)
            for type in ComplianceType.defaults(for: region) {
                let item = ComplianceItem(type: type)
                context.insert(item)
                item.property = target
            }
        }
        target.nickname = nickname.trimmingCharacters(in: .whitespaces)
        target.addressLine1 = addressLine1.trimmingCharacters(in: .whitespaces)
        target.addressLine2 = addressLine2.trimmingCharacters(in: .whitespaces)
        target.city = city.trimmingCharacters(in: .whitespaces)
        target.state = state.trimmingCharacters(in: .whitespaces)
        target.postcode = postcode.trimmingCharacters(in: .whitespaces)
        target.region = region
        target.type = type
        target.furnishing = furnishing
        target.bedrooms = bedrooms
        target.bathrooms = bathrooms
        target.notes = notes
        if let coverImage, let saved = PhotoStore.shared.save(coverImage, maxDimension: 1600) {
            if let old = target.coverPhotoFilename { PhotoStore.shared.delete(old) }
            target.coverPhotoFilename = saved.filename
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
