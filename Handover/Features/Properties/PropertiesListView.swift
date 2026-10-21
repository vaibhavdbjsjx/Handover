import SwiftUI
import SwiftData

struct PropertiesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @Query(sort: \Property.createdAt, order: .reverse) private var properties: [Property]
    @Query private var inspections: [Inspection]
    @Query private var complianceItems: [ComplianceItem]

    @State private var showingEditor = false
    @State private var showingPaywall = false
    @AppStorage(PrefKey.userName) private var userName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if properties.isEmpty {
                        EmptyStateView(
                            symbol: "house.and.flag.fill",
                            title: "Add your first property",
                            message: "Set up a property once, then create check-in and check-out reports in minutes.",
                            actionTitle: "Add property",
                            action: addProperty
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                        Button {
                            SampleData.insert(into: context)
                            Haptics.success()
                        } label: {
                            Label("Explore a sample report", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        statsRow
                        LazyVStack(spacing: 14) {
                            ForEach(properties) { property in
                                NavigationLink(value: property) {
                                    PropertyCard(property: property)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationDestination(for: Property.self) { PropertyDetailView(property: $0) }
            .navigationDestination(for: Inspection.self) { InspectionView(inspection: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addProperty) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add property")
                }
            }
            .sheet(isPresented: $showingEditor) {
                PropertyEditorView(property: nil)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: .moreProperties)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Your properties")
                .font(.display(34, weight: .bold))
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        let first = userName.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? part : "\(part), \(first)"
    }

    private var statsRow: some View {
        let dueSoon = complianceItems.filter { $0.urgency == .dueSoon || $0.urgency == .overdue }.count
        return HStack(spacing: 12) {
            StatTile(value: "\(properties.count)", label: properties.count == 1 ? "Property" : "Properties", symbol: "house.fill")
            StatTile(value: "\(inspections.count)", label: "Reports", symbol: "doc.text.fill")
            StatTile(value: "\(dueSoon)", label: "Due soon", symbol: "bell.fill")
        }
    }

    private func addProperty() {
        if !store.isPro && properties.filter({ !$0.isSample }).count >= AppConfig.freeProperties {
            showingPaywall = true
        } else {
            showingEditor = true
        }
    }
}

struct PropertyCard: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                PropertyCover(property: property, height: 150)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(property.displayName)
                        .font(.display(22))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !property.fullAddress.isEmpty && property.fullAddress != property.displayName {
                        Text(property.fullAddress)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .padding(14)
            }
            .frame(height: 150)
            .clipped()

            HStack(spacing: 8) {
                Pill(text: "\(property.bedrooms) bed", color: .secondary, symbol: "bed.double.fill")
                Pill(text: property.furnishing.label, color: .secondary)
                Spacer()
                if let latest = property.sortedInspections.first {
                    Pill(text: "\(latest.region.shortName(for: latest.kind)) · \(latest.status.label)", color: latest.status == .signed ? Theme.accent : Theme.gold)
                } else {
                    Pill(text: "No reports yet", color: Theme.gold)
                }
            }
            .padding(12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

struct PropertyCover: View {
    let property: Property
    var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            if let cover = property.coverPhotoFilename {
                FillPhoto(filename: cover, aspect: proxy.size.width / max(height, 1))
                    .frame(width: proxy.size.width, height: height)
            } else {
                ZStack {
                    Theme.heroGradient
                    Image(systemName: property.type.symbol)
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Theme.gold.opacity(0.55))
                        .offset(x: proxy.size.width * 0.28, y: -10)
                }
                .frame(width: proxy.size.width, height: height)
            }
        }
        .frame(height: height)
    }
}
