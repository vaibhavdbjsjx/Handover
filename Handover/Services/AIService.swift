import UIKit

/// Talks to the Handover AI proxy. The proxy holds the model API key and the
/// prompts, so neither ever ships inside the app.
final class AIService {
    static let shared = AIService()

    enum AIError: LocalizedError {
        case notConfigured
        case noPhotos
        case server(String)
        case quota
        case network

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "The AI service isn't set up in this build yet."
            case .noPhotos: return "Take at least one photo of the room first."
            case .server(let message): return message
            case .quota: return "You've reached today's AI limit. It resets tomorrow."
            case .network: return "Couldn't reach the AI service. Check your connection and try again."
            }
        }
    }

    // MARK: Describe

    struct DescribeRequest: Encodable {
        let region: String
        let roomName: String
        let roomType: String
        let furnishing: String
        let items: [String]
        let images: [String]
    }

    struct DescribedItem: Decodable {
        let name: String
        let description: String
        let condition: String
        let cleanliness: String
    }

    struct DescribeResponse: Decodable {
        let summary: String
        let items: [DescribedItem]
    }

    func describeRoom(name: String, kind: RoomKind, furnishing: Furnishing, region: Region, itemNames: [String], photos: [UIImage]) async throws -> DescribeResponse {
        guard !photos.isEmpty else { throw AIError.noPhotos }
        let images = photos.prefix(8).compactMap { $0.jpegBase64() }
        let body = DescribeRequest(region: region.rawValue, roomName: name, roomType: kind.label, furnishing: furnishing.label, items: itemNames, images: images)
        return try await post(path: "v1/describe-room", body: body)
    }

    // MARK: Compare

    struct CompareItem: Encodable {
        let name: String
        let baselineDescription: String
        let baselineCondition: String
        let baselineCleanliness: String
    }

    struct CompareRequest: Encodable {
        let region: String
        let currency: String
        let roomName: String
        let items: [CompareItem]
        let baselineImages: [String]
        let currentImages: [String]
    }

    struct ComparedItem: Decodable {
        let name: String
        let change: String
        let note: String
        let description: String?
        let condition: String?
        let cleanliness: String?
        let suggestedDeduction: Double?
    }

    struct CompareResponse: Decodable {
        let summary: String
        let items: [ComparedItem]
    }

    func compareRoom(name: String, region: Region, items: [CompareItem], baselinePhotos: [UIImage], currentPhotos: [UIImage]) async throws -> CompareResponse {
        guard !currentPhotos.isEmpty else { throw AIError.noPhotos }
        let body = CompareRequest(
            region: region.rawValue,
            currency: region.currencyCode,
            roomName: name,
            items: items,
            baselineImages: baselinePhotos.prefix(5).compactMap { $0.jpegBase64(maxDimension: 1024) },
            currentImages: currentPhotos.prefix(5).compactMap { $0.jpegBase64(maxDimension: 1024) }
        )
        return try await post(path: "v1/compare-room", body: body)
    }

    // MARK: Transport

    private struct ErrorBody: Decodable { let error: String }

    private func post<Body: Encodable, Response: Decodable>(path: String, body: Body) async throws -> Response {
        guard let base = AppConfig.apiBaseURL else { throw AIError.notConfigured }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(Preferences.deviceID, forHTTPHeaderField: "X-Device-ID")
        request.setValue(AppConfig.version, forHTTPHeaderField: "X-App-Version")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 { throw AIError.quota }
        guard (200..<300).contains(status) else {
            if let message = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw AIError.server(message.error)
            }
            throw AIError.server("The AI service returned an error (\(status)). Please try again.")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AIError.server("The AI returned something unexpected. Please try again.")
        }
    }
}

// MARK: - Applying results

extension Condition {
    init(aiValue: String?) {
        switch aiValue?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "excellent": self = .excellent
        case "good": self = .good
        case "fair": self = .fair
        case "poor": self = .poor
        case "damaged": self = .damaged
        case "n/a", "na", "not applicable", "notapplicable": self = .notApplicable
        default: self = .good
        }
    }
}

extension Cleanliness {
    init(aiValue: String?) {
        switch aiValue?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "professional", "professionally clean": self = .professional
        case "clean": self = .clean
        case "needs attention", "needsattention", "needs_attention": self = .needsAttention
        case "dirty": self = .dirty
        case "n/a", "na", "not applicable", "notapplicable": self = .notApplicable
        default: self = .clean
        }
    }
}

extension ChangeKind {
    init(aiValue: String?) {
        switch aiValue?.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "") {
        case "nochange", "none": self = .noChange
        case "fairwear", "fairwearandtear", "wear": self = .fairWear
        case "cleaning", "cleaningrequired": self = .cleaning
        case "damage", "damaged": self = .damage
        case "missing": self = .missing
        default: self = .unassessed
        }
    }
}
