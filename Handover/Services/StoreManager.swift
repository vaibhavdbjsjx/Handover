import Foundation
import StoreKit
import Observation

/// StoreKit 2 purchases: the Pro subscription and single-report credits.
@MainActor
@Observable
final class StoreManager {
    static let monthlyID = "handover.pro.monthly"
    static let yearlyID = "handover.pro.yearly"
    static let singleReportID = "handover.report.single"
    static let subscriptionIDs: Set<String> = [monthlyID, yearlyID]
    static let allIDs: [String] = [yearlyID, monthlyID, singleReportID]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var activeProductID: String?
    private(set) var renewalDate: Date?
    private(set) var isLoading = false
    private(set) var eligibleForTrial = true
    var lastError: String?

    private(set) var reportCredits: Int = UserDefaults.standard.integer(forKey: PrefKey.reportCredits)
    private(set) var aiRoomsUsed: Int = UserDefaults.standard.integer(forKey: PrefKey.aiRoomsUsed)
    private(set) var freeReportUsedFor: String? = UserDefaults.standard.string(forKey: "freeReportUsedFor")

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    var yearly: Product? { products.first { $0.id == Self.yearlyID } }
    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var singleReport: Product? { products.first { $0.id == Self.singleReportID } }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            products = loaded.sorted { $0.price > $1.price }
            if let yearly, let subscription = yearly.subscription {
                eligibleForTrial = await subscription.isEligibleForIntroOffer
            }
        } catch {
            lastError = "Couldn't load prices. Check your connection."
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var pro = false
        var productID: String?
        var expiry: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.subscriptionIDs.contains(transaction.productID), transaction.revocationDate == nil {
                pro = true
                productID = transaction.productID
                expiry = transaction.expirationDate
            }
        }
        isPro = pro
        activeProductID = productID
        renewalDate = expiry
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "The purchase couldn't be verified."
                    return false
                }
                await apply(transaction)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Restore didn't complete. Please try again."
        }
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await apply(transaction)
        await transaction.finish()
    }

    private func apply(_ transaction: Transaction) async {
        if transaction.productID == Self.singleReportID {
            guard transaction.revocationDate == nil else { return }
            addCredits(transaction.purchasedQuantity)
        } else {
            await refreshEntitlements()
        }
    }

    // MARK: Credits and free allowance

    private func addCredits(_ count: Int) {
        reportCredits += count
        UserDefaults.standard.set(reportCredits, forKey: PrefKey.reportCredits)
    }

    /// Whether a report can be exported without a watermark.
    func canExport(_ inspection: Inspection) -> Bool {
        // The sample report never uses up the free export.
        if inspection.property?.isSample == true { return isPro }
        return isPro || inspection.unlockedByCredit || freeReportUsedFor == inspection.id.uuidString || freeReportUsedFor == nil
    }

    /// Records how an export was paid for. Call only after `canExport` is true.
    func consumeExport(for inspection: Inspection) {
        if isPro || inspection.unlockedByCredit || freeReportUsedFor == inspection.id.uuidString { return }
        if freeReportUsedFor == nil {
            freeReportUsedFor = inspection.id.uuidString
            UserDefaults.standard.set(freeReportUsedFor, forKey: "freeReportUsedFor")
        }
    }

    var hasFreeReport: Bool { freeReportUsedFor == nil }

    /// Spends one purchased credit to unlock a report permanently.
    func spendCredit(on inspection: Inspection) -> Bool {
        guard reportCredits > 0 else { return false }
        reportCredits -= 1
        UserDefaults.standard.set(reportCredits, forKey: PrefKey.reportCredits)
        inspection.unlockedByCredit = true
        return true
    }

    var canUseAI: Bool { isPro || aiRoomsUsed < AppConfig.freeAIRooms }

    var freeAIRemaining: Int { max(0, AppConfig.freeAIRooms - aiRoomsUsed) }

    func recordAIUse() {
        guard !isPro else { return }
        aiRoomsUsed += 1
        UserDefaults.standard.set(aiRoomsUsed, forKey: PrefKey.aiRoomsUsed)
    }

    var planName: String {
        switch activeProductID {
        case Self.yearlyID: return "Pro · Yearly"
        case Self.monthlyID: return "Pro · Monthly"
        default: return isPro ? "Pro" : "Free"
        }
    }
}
