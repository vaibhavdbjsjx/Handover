import UIKit
import CryptoKit
import ImageIO

/// Stores evidence photos and signatures as files on disk, and hashes each
/// photo at capture time so any later edit to the file can be detected.
final class PhotoStore {
    static let shared = PhotoStore()

    private let directory: URL
    private let cache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Evidence", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cache.countLimit = 40
        thumbnailCache.countLimit = 400
    }

    struct SavedImage {
        let filename: String
        let sha256: String
    }

    func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    /// Saves a photo as JPEG, capped at 2400px on the long edge.
    func save(_ image: UIImage, maxDimension: CGFloat = 2400, quality: CGFloat = 0.85) -> SavedImage? {
        let resized = image.resized(maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        return save(data: data, ext: "jpg")
    }

    /// Saves a PNG with transparency (used for signatures and logos).
    func savePNG(_ image: UIImage) -> SavedImage? {
        guard let data = image.pngData() else { return nil }
        return save(data: data, ext: "png")
    }

    private func save(data: Data, ext: String) -> SavedImage? {
        let filename = "\(UUID().uuidString).\(ext)"
        do {
            try data.write(to: url(for: filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return SavedImage(filename: filename, sha256: Self.sha256(data))
        } catch {
            return nil
        }
    }

    func image(_ filename: String) -> UIImage? {
        if let cached = cache.object(forKey: filename as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(for: filename).path) else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }

    func data(_ filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    /// Fast downsampled thumbnail that never decodes the full image.
    func thumbnail(_ filename: String, maxPixel: CGFloat = 400) -> UIImage? {
        let key = "\(filename)-\(Int(maxPixel))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url(for: filename) as CFURL, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    func delete(_ filename: String) {
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// Re-hashes a stored file and compares it with the hash taken at capture.
    func verify(_ filename: String, expected: String) -> Bool {
        guard let data = data(filename) else { return false }
        return Self.sha256(data) == expected
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }

    /// Removes files no longer referenced by any record.
    func removeOrphans(keeping filenames: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for file in contents where !filenames.contains(file) {
            try? FileManager.default.removeItem(at: url(for: file))
        }
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return normalizedOrientation() }
        let scale = maxDimension / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func jpegBase64(maxDimension: CGFloat = 1280, quality: CGFloat = 0.7) -> String? {
        resized(maxDimension: maxDimension).jpegData(compressionQuality: quality)?.base64EncodedString()
    }
}
