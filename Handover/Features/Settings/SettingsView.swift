import SwiftUI
import SwiftData
import PhotosUI
import StoreKit

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @AppStorage(PrefKey.userName) private var userName = ""
    @AppStorage(PrefKey.companyName) private var companyName = ""
    @AppStorage(PrefKey.userEmail) private var userEmail = ""
    @AppStorage(PrefKey.userPhone) private var userPhone = ""
    @AppStorage(PrefKey.region) private var regionRaw = Region.deviceDefault.rawValue
    @AppStorage(PrefKey.tagLocation) private var tagLocation = true
    @AppStorage(PrefKey.aiConsent) private var aiConsent = false
    @AppStorage(PrefKey.logoFilename) private var logoFilename = ""

    @State private var showingPaywall = false
    @State private var logoItem: PhotosPickerItem?
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    planCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    TextField("Your name", text: $userName)
                        .textContentType(.name)
                    TextField("Company (optional)", text: $companyName)
                        .textContentType(.organizationName)
                    TextField("Email", text: $userEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $userPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        HStack {
                            Text("Report logo")
                            Spacer()
                            if !logoFilename.isEmpty, let image = PhotoStore.shared.image(logoFilename) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 28)
                            } else {
                                Text("Add").foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !logoFilename.isEmpty {
                        Button("Remove logo", role: .destructive) {
                            PhotoStore.shared.delete(logoFilename)
                            logoFilename = ""
                        }
                    }
                } header: {
                    Text("Your details")
                } footer: {
                    Text("Shown on the cover of every report.")
                }

                Section {
                    Picker("Country", selection: $regionRaw) {
                        ForEach(Region.allCases) { Text("\($0.flag)  \($0.displayName)").tag($0.rawValue) }
                    }
                } header: {
                    Text("Region")
                } footer: {
                    Text("Sets the default for new properties: report names, currency, paper size, deposit schemes and compliance checks.")
                }

                Section {
                    Toggle("Tag photos with location", isOn: $tagLocation)
                    Toggle("Allow AI to read room photos", isOn: $aiConsent)
                } header: {
                    Text("Evidence & privacy")
                } footer: {
                    Text("Location is stored only in your reports on this device. AI photos are processed by Google Gemini through Handover's server and are not stored.")
                }

                Section("Support") {
                    Link(destination: supportMailURL) {
                        Label("Contact support", systemImage: "envelope.fill")
                    }
                    Link(destination: AppConfig.supportURL) {
                        Label("Help centre", systemImage: "questionmark.circle.fill")
                    }
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate Handover", systemImage: "star.fill")
                    }
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Label("Restore purchases", systemImage: "arrow.clockwise")
                    }
                }

                Section("Legal") {
                    Link("Privacy policy", destination: AppConfig.privacyURL)
                    Link("Terms of service", destination: AppConfig.termsURL)
                    Link("Apple standard EULA", destination: AppConfig.appleEULA)
                }

                Section {
                    Button("Delete all data", role: .destructive) { confirmErase = true }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your reports and photos are stored only on this iPhone and in your iCloud device backup. Handover has no account and keeps no copy.")
                        Text("Handover \(AppConfig.version)")
                            .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: .general) }
            .confirmationDialog("Delete everything?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Delete all properties, reports and photos", role: .destructive, action: eraseAll)
            } message: {
                Text("This can't be undone. Export any reports you want to keep first.")
            }
            .onChange(of: logoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data),
                       let saved = PhotoStore.shared.savePNG(image.resized(maxDimension: 600)) {
                        if !logoFilename.isEmpty { PhotoStore.shared.delete(logoFilename) }
                        logoFilename = saved.filename
                    }
                }
            }
        }
    }

    private var supportMailURL: URL {
        let subject = "Handover support (\(AppConfig.version))".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Handover%20support"
        return URL(string: "mailto:\(AppConfig.supportEmail)?subject=\(subject)") ?? AppConfig.supportURL
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HANDOVER")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(Theme.gold)
                    Text(store.planName)
                        .font(.display(26, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: store.isPro ? "checkmark.seal.fill" : "key.horizontal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.gold)
            }
            if store.isPro {
                if let renewal = store.renewalDate {
                    Text("Renews or ends \(renewal.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Link(destination: AppConfig.manageSubscriptionsURL) {
                    Text("Manage subscription")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
            } else {
                Text(store.hasFreeReport ? "Your first report export is free. \(store.freeAIRemaining) free AI rooms left." : "\(store.freeAIRemaining) free AI rooms left. \(store.reportCredits) report credits.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Button { showingPaywall = true } label: {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundStyle(Theme.deepGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func eraseAll() {
        let properties = (try? context.fetch(FetchDescriptor<Property>())) ?? []
        for property in properties {
            InspectionFactory.delete(property, in: context)
        }
        try? context.save()
        PhotoStore.shared.removeOrphans(keeping: logoFilename.isEmpty ? [] : [logoFilename])
        Haptics.success()
    }
}
