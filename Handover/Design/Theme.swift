import SwiftUI

enum Theme {
    static let accent = Color.accentColor
    static let ink = Color("BrandInk")
    static let gold = Color("BrandGold")
    static let evergreen = Color(red: 0.118, green: 0.361, blue: 0.290)
    static let deepGreen = Color(red: 0.043, green: 0.141, blue: 0.118)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let hairline = Color.primary.opacity(0.08)

    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.122, green: 0.361, blue: 0.290), Color(red: 0.043, green: 0.141, blue: 0.118)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let radius: CGFloat = 18
    static let smallRadius: CGFloat = 12
}

extension Font {
    /// Editorial serif used for titles, which gives the app its premium feel.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var isProminent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isProminent ? Color.white : Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isProminent {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.heroGradient)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent.opacity(0.12))
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var secondary: PrimaryButtonStyle { PrimaryButtonStyle(isProminent: false) }
}

// MARK: - Pills

struct Pill: View {
    let text: String
    var color: Color = Theme.accent
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(color)
        .background(color.opacity(0.13), in: Capsule())
    }
}

struct ConditionPill: View {
    let condition: Condition
    var body: some View { Pill(text: condition.label, color: condition.color) }
}

struct ChangePill: View {
    let change: ChangeKind
    var body: some View { Pill(text: change.label, color: change.color, symbol: change.symbol) }
}

// MARK: - Section header

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.display(22))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 5
    var color: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text(value)
                .font(.display(24))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .card(padding: 14)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.1)).frame(width: 88, height: 88)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .font(.display(22))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
    }
}

// MARK: - Photo thumbnail

struct PhotoThumbnail: View {
    let filename: String
    var size: CGFloat = 76
    var cornerRadius: CGFloat = 12

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.12))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: filename) {
            let name = filename
            let pixel = size * 3
            image = await Task.detached(priority: .userInitiated) {
                PhotoStore.shared.thumbnail(name, maxPixel: pixel)
            }.value
        }
    }
}

/// A thumbnail that fills the width it is given, used in grids.
struct FillPhoto: View {
    let filename: String
    var aspect: CGFloat = 1

    @State private var image: UIImage?

    var body: some View {
        Color.secondary.opacity(0.12)
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: filename) {
                let name = filename
                image = await Task.detached(priority: .userInitiated) {
                    PhotoStore.shared.thumbnail(name, maxPixel: 700)
                }.value
            }
    }
}

// MARK: - Haptics

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func shutter() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}
