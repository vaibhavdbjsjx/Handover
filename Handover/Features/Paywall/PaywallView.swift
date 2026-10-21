import SwiftUI
import StoreKit

struct PaywallView: View {
    enum Reason {
        case general, export, ai, moreProperties

        var headline: String {
            switch self {
            case .general: return "Reports that win disputes"
            case .export: return "Export your signed report"
            case .ai: return "Let AI write every room"
            case .moreProperties: return "Manage your whole portfolio"
            }
        }

        var subheadline: String {
            switch self {
            case .general: return "Everything you need for professional check-ins, check-outs and deposit claims."
            case .export: return "Share clerk-quality PDF reports with tenants, agents and deposit schemes."
            case .ai: return "You've used your free AI rooms. Go Pro for unlimited descriptions and comparisons."
            case .moreProperties: return "Add unlimited properties and keep every report and certificate in one place."
            }
        }
    }

    let reason: Reason

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store
    @State private var selectedID: String = StoreManager.yearlyID
    @State private var isPurchasing = false

    private let features: [(String, String, String)] = [
        ("doc.richtext.fill", "Unlimited reports", "Check-in, check-out and interim reports for every property."),
        ("sparkles", "AI descriptions", "Clerk-style wording for every item, written from your photos."),
        ("rectangle.on.rectangle.angled", "Check-out comparison", "Side-by-side evidence and a ready-made deposit claim."),
        ("checkmark.seal.fill", "Tamper-evident evidence", "Timestamped, fingerprinted photos and signatures."),
        ("house.and.flag.fill", "Unlimited properties", "Plus compliance reminders for each one.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                featureList
                plans
                if let error = store.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                legal
            }
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) { ctaBar }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.25), in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close")
        }
        .task {
            if store.products.isEmpty { await store.load() }
            if reason == .export && store.isPro { dismiss() }
        }
        .onChange(of: store.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.heroGradient
            Circle()
                .fill(Theme.gold.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 160, y: -80)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "key.horizontal.fill")
                    Text("HANDOVER PRO")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                }
                .foregroundStyle(Theme.gold)
                Text(reason.headline)
                    .font(.display(32, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(reason.subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .padding(.top, 60)
        }
        .frame(minHeight: 270)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
        .ignoresSafeArea(edges: .top)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(features, id: \.1) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.0)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.1).font(.headline)
                        Text(feature.2).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if store.products.isEmpty {
                ProgressView().padding()
            }
            if let yearly = store.yearly {
                PlanCard(
                    title: "Yearly",
                    price: "\(yearly.displayPrice) per year",
                    detail: monthlyEquivalent(yearly).map { "Just \($0) a month" } ?? "",
                    badge: store.eligibleForTrial && yearly.subscription?.introductoryOffer != nil ? "7-DAY FREE TRIAL" : "BEST VALUE",
                    isSelected: selectedID == yearly.id
                ) { selectedID = yearly.id }
            }
            if let monthly = store.monthly {
                PlanCard(title: "Monthly", price: "\(monthly.displayPrice) per month", detail: "Cancel anytime", badge: nil, isSelected: selectedID == monthly.id) {
                    selectedID = monthly.id
                }
            }
            if let single = store.singleReport, reason == .export {
                PlanCard(title: "Just this report", price: "\(single.displayPrice) one-time", detail: "Unlock one report forever. No subscription.", badge: nil, isSelected: selectedID == single.id) {
                    selectedID = single.id
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func monthlyEquivalent(_ product: Product) -> String? {
        let monthly = product.price / 12
        return monthly.formatted(product.priceFormatStyle)
    }

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedID }
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Continue" }
        if product.id == StoreManager.yearlyID && store.eligibleForTrial && product.subscription?.introductoryOffer != nil {
            return "Start 7-day free trial"
        }
        if product.id == StoreManager.singleReportID { return "Buy for \(product.displayPrice)" }
        return "Subscribe for \(product.displayPrice)"
    }

    private var ctaFootnote: String {
        guard let product = selectedProduct else { return "" }
        switch product.id {
        case StoreManager.yearlyID:
            if store.eligibleForTrial && product.subscription?.introductoryOffer != nil {
                return "Free for 7 days, then \(product.displayPrice) per year. Cancel anytime."
            }
            return "\(product.displayPrice) per year. Renews automatically. Cancel anytime."
        case StoreManager.monthlyID:
            return "\(product.displayPrice) per month. Renews automatically. Cancel anytime."
        default:
            return "One-time purchase. Unlocks export for one report."
        }
    }

    private var ctaBar: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selectedProduct else { return }
                isPurchasing = true
                Task {
                    let success = await store.purchase(product)
                    isPurchasing = false
                    if success {
                        Haptics.success()
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if isPurchasing { ProgressView().tint(.white) }
                    Text(ctaTitle)
                }
            }
            .buttonStyle(.primary)
            .disabled(selectedProduct == nil || isPurchasing)
            Text(ctaFootnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
    }

    private var legal: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Button("Restore purchases") {
                    Task { await store.restore() }
                }
                Link("Terms of Use", destination: AppConfig.appleEULA)
                Link("Privacy", destination: AppConfig.privacyURL)
            }
            .font(.footnote.weight(.semibold))
            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple Account at confirmation of purchase. Manage or cancel in your App Store account settings. Any unused part of a free trial is forfeited when you buy a subscription.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.gold, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    Text(price).font(.subheadline.weight(.medium))
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}
