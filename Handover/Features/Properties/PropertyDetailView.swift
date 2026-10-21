import SwiftUI
import SwiftData

struct PropertyDetailView: View {
    @Bindable var property: Property

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditor = false
    @State private var confirmDelete = false
    @State private var newInspection: Inspection?
    @State private var showingBaselinePicker = false
    @State private var followUpKind: InspectionKind = .checkOut
    @State private var showingNoBaselineAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                actions
                reportsSection
                complianceSection
                if !property.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("Notes")
                        Text(property.notes)
                            .font(.callout)
                            .card()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle(property.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEditor = true } label: { Label("Edit property", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete property", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) { PropertyEditorView(property: property) }
        .confirmationDialog("Delete \(property.displayName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete property and all reports", role: .destructive) {
                let target = property
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    InspectionFactory.delete(target, in: context)
                    try? context.save()
                }
            }
        } message: {
            Text("This permanently deletes every report and photo for this property. Export any reports you need first.")
        }
        .confirmationDialog("Compare against which \(property.region.shortName(for: .checkIn).lowercased())?", isPresented: $showingBaselinePicker, titleVisibility: .visible) {
            ForEach(property.sortedInspections.filter { $0.kind == .checkIn }) { baseline in
                Button("\(baseline.date.formatted(date: .abbreviated, time: .omitted)) · \(baseline.status.label)") {
                    startFollowUp(baseline: baseline)
                }
            }
        }
        .alert("No \(property.region.shortName(for: .checkIn).lowercased()) yet", isPresented: $showingNoBaselineAlert) {
            Button("Start \(property.region.shortName(for: .checkIn).lowercased())") { startCheckIn() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A \(property.region.shortName(for: followUpKind).lowercased()) compares each room against the \(property.region.shortName(for: .checkIn).lowercased()) report, so create that first.")
        }
        .navigationDestination(item: $newInspection) { InspectionView(inspection: $0) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertyCover(property: property, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(property.displayName)
                    .font(.display(28, weight: .bold))
                if !property.fullAddress.isEmpty {
                    Text(property.fullAddress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Pill(text: property.type.label, color: .secondary, symbol: property.type.symbol)
                    Pill(text: "\(property.bedrooms) bed · \(property.bathrooms) bath", color: .secondary)
                    Pill(text: property.region.flag, color: .secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: startCheckIn) {
                Label("New \(property.region.shortName(for: .checkIn).lowercased()) report", systemImage: InspectionKind.checkIn.symbol)
            }
            .buttonStyle(.primary)

            HStack(spacing: 10) {
                Button { requestFollowUp(.checkOut) } label: {
                    Label(property.region.shortName(for: .checkOut), systemImage: InspectionKind.checkOut.symbol)
                }
                .buttonStyle(.secondary)
                Button { requestFollowUp(.interim) } label: {
                    Label("Interim", systemImage: InspectionKind.interim.symbol)
                }
                .buttonStyle(.secondary)
            }
        }
    }

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Reports", subtitle: property.inspections.isEmpty ? "Reports you create appear here." : nil)
            ForEach(property.sortedInspections) { inspection in
                NavigationLink(value: inspection) {
                    InspectionRow(inspection: inspection)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle("Compliance")
                NavigationLink("See all") { PropertyComplianceView(property: property) }
                    .font(.subheadline.weight(.semibold))
            }
            let upcoming = property.complianceItems
                .filter { $0.expiresAt != nil }
                .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
                .prefix(3)
            if upcoming.isEmpty {
                NavigationLink {
                    PropertyComplianceView(property: property)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add certificate dates").font(.headline)
                            Text("Get reminded before gas, electrical and other checks expire.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcoming)) { item in
                        ComplianceRow(item: item)
                            .padding(.vertical, 10)
                        if item.id != upcoming.last?.id { Divider() }
                    }
                }
                .card(padding: 14)
            }
        }
    }

    private func startCheckIn() {
        let inspection = InspectionFactory.makeCheckIn(for: property, in: context)
        try? context.save()
        newInspection = inspection
    }

    private func requestFollowUp(_ kind: InspectionKind) {
        followUpKind = kind
        let checkIns = property.inspections.filter { $0.kind == .checkIn }
        if checkIns.isEmpty {
            showingNoBaselineAlert = true
        } else if checkIns.count == 1, let only = checkIns.first {
            startFollowUp(baseline: only)
        } else {
            showingBaselinePicker = true
        }
    }

    private func startFollowUp(baseline: Inspection) {
        let inspection = InspectionFactory.makeFollowUp(kind: followUpKind, for: property, baseline: baseline, in: context)
        try? context.save()
        newInspection = inspection
    }
}

struct InspectionRow: View {
    let inspection: Inspection

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: inspection.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(inspection.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if inspection.status == .signed {
                Pill(text: "Signed", color: Theme.accent, symbol: "checkmark.seal.fill")
            } else {
                ProgressRing(progress: inspection.progress, lineWidth: 4)
                    .frame(width: 28, height: 28)
            }
        }
        .card(padding: 12)
    }

    private var subtitle: String {
        var parts = [inspection.date.formatted(date: .abbreviated, time: .omitted)]
        if !inspection.tenantNames.isEmpty { parts.append(inspection.tenantNames) }
        parts.append("\(inspection.photoCount) photos")
        return parts.joined(separator: " · ")
    }
}
