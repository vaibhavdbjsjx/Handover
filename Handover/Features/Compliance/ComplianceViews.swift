import SwiftUI
import SwiftData

struct RemindersView: View {
    @Query private var items: [ComplianceItem]
    @Query(sort: \Property.createdAt) private var properties: [Property]

    private var dated: [ComplianceItem] {
        items.filter { $0.expiresAt != nil }.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    private var overdue: [ComplianceItem] { dated.filter { $0.urgency == .overdue } }
    private var dueSoon: [ComplianceItem] { dated.filter { $0.urgency == .dueSoon } }
    private var later: [ComplianceItem] { dated.filter { $0.urgency == .ok } }
    private var undated: [ComplianceItem] { items.filter { $0.expiresAt == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay compliant")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Reminders")
                            .font(.display(34, weight: .bold))
                    }
                    .padding(.top, 8)

                    if properties.isEmpty {
                        EmptyStateView(symbol: "bell.badge", title: "No reminders yet", message: "Add a property and Handover will suggest the certificates and checks to track for your country.")
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 12) {
                            StatTile(value: "\(overdue.count)", label: "Overdue", symbol: "exclamationmark.circle.fill")
                            StatTile(value: "\(dueSoon.count)", label: "Due soon", symbol: "clock.fill")
                            StatTile(value: "\(later.count)", label: "Up to date", symbol: "checkmark.circle.fill")
                        }
                        group("Overdue", overdue)
                        group("Due soon", dueSoon)
                        group("Later", later)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle("By property")
                            ForEach(properties) { property in
                                NavigationLink {
                                    PropertyComplianceView(property: property)
                                } label: {
                                    HStack {
                                        Image(systemName: property.type.symbol)
                                            .foregroundStyle(Theme.accent)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(property.displayName).font(.headline)
                                            let missing = property.complianceItems.filter { $0.expiresAt == nil }.count
                                            Text(missing > 0 ? "\(missing) without a date" : "All dates set")
                                                .font(.footnote)
                                                .foregroundStyle(missing > 0 ? Theme.gold : .secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                    }
                                    .card(padding: 14)
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
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ list: [ComplianceItem]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title)
                VStack(spacing: 0) {
                    ForEach(list) { item in
                        NavigationLink {
                            ComplianceEditorView(item: item, property: item.property)
                        } label: {
                            ComplianceRow(item: item, showProperty: true)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if item.id != list.last?.id { Divider() }
                    }
                }
                .card(padding: 14)
            }
        }
    }
}

struct ComplianceRow: View {
    let item: ComplianceItem
    var showProperty = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: item.type.symbol).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(badge)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
        .contentShape(Rectangle())
    }

    private var color: Color {
        switch item.urgency {
        case .overdue: return ChangeKind.damage.color
        case .dueSoon: return Theme.gold
        case .ok: return Theme.accent
        case .unknown: return .secondary
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if showProperty, let property = item.property { parts.append(property.displayName) }
        if let expires = item.expiresAt {
            parts.append("Due \(expires.formatted(date: .abbreviated, time: .omitted))")
        } else {
            parts.append("No date set")
        }
        return parts.joined(separator: " · ")
    }

    private var badge: String {
        guard let days = item.daysRemaining else { return "Set date" }
        if days < 0 { return "\(-days)d overdue" }
        if days == 0 { return "Today" }
        if days < 60 { return "\(days)d" }
        let months = days / 30
        return "\(months)mo"
    }
}

struct PropertyComplianceView: View {
    @Bindable var property: Property
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                ForEach(property.complianceItems.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }) { item in
                    NavigationLink {
                        ComplianceEditorView(item: item, property: property)
                    } label: {
                        ComplianceRow(item: item)
                    }
                }
                .onDelete { offsets in
                    let sorted = property.complianceItems.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
                    for index in offsets {
                        ReminderService.cancel(sorted[index])
                        context.delete(sorted[index])
                    }
                }
            } footer: {
                Text("Reminders arrive at 9am on the day you choose before each date. Requirements vary by location, so check your local rules.")
            }
        }
        .navigationTitle("Compliance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add reminder")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { ComplianceEditorView(item: nil, property: property) }
        }
    }
}

struct ComplianceEditorView: View {
    let item: ComplianceItem?
    let property: Property?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var type: ComplianceType = .gasSafety
    @State private var title = ""
    @State private var hasIssued = false
    @State private var issuedAt = Date.now
    @State private var hasExpiry = true
    @State private var expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var reminderDays = 30
    @State private var notes = ""
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $type) {
                    ForEach(ComplianceType.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                TextField("Title", text: $title)
            } footer: {
                Text(type.guidance)
            }

            Section("Dates") {
                Toggle("Issued or completed", isOn: $hasIssued)
                if hasIssued {
                    DatePicker("Date", selection: $issuedAt, displayedComponents: .date)
                }
                Toggle("Expiry or due date", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("Due", selection: $expiresAt, displayedComponents: .date)
                    Picker("Remind me", selection: $reminderDays) {
                        Text("1 week before").tag(7)
                        Text("2 weeks before").tag(14)
                        Text("30 days before").tag(30)
                        Text("60 days before").tag(60)
                        Text("90 days before").tag(90)
                    }
                }
            }

            Section("Notes") {
                TextField("Certificate number, engineer, contact…", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle(item == nil ? "New reminder" : "Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if item == nil {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).fontWeight(.semibold)
            }
        }
        .onAppear(perform: load)
        .onChange(of: issuedAt) { _, newValue in
            if let months = type.typicalValidityMonths, item?.expiresAt == nil {
                expiresAt = Calendar.current.date(byAdding: .month, value: months, to: newValue) ?? expiresAt
            }
        }
        .onChange(of: type) { oldValue, newValue in
            if title.isEmpty || title == oldValue.label { title = newValue.label }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let item {
            type = item.type
            title = item.title
            hasIssued = item.issuedAt != nil
            issuedAt = item.issuedAt ?? .now
            hasExpiry = item.expiresAt != nil || item.issuedAt == nil
            if let expiry = item.expiresAt {
                expiresAt = expiry
            } else if let months = item.type.typicalValidityMonths {
                expiresAt = Calendar.current.date(byAdding: .month, value: months, to: .now) ?? .now
            }
            reminderDays = item.reminderDaysBefore
            notes = item.notes
        } else {
            title = type.label
        }
    }

    private func save() {
        let target: ComplianceItem
        if let item {
            target = item
        } else {
            target = ComplianceItem(type: type)
            context.insert(target)
            target.property = property
        }
        target.type = type
        target.title = title.trimmingCharacters(in: .whitespaces).isEmpty ? type.label : title
        target.issuedAt = hasIssued ? issuedAt : nil
        target.expiresAt = hasExpiry ? expiresAt : nil
        target.reminderDaysBefore = reminderDays
        target.notes = notes
        try? context.save()
        Task {
            if await ReminderService.requestPermission() {
                ReminderService.schedule(target)
            }
        }
        Haptics.success()
        dismiss()
    }
}
