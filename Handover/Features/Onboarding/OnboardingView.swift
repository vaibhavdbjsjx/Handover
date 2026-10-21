import SwiftUI

struct OnboardingView: View {
    @AppStorage(PrefKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PrefKey.region) private var regionRaw = Region.deviceDefault.rawValue
    @AppStorage(PrefKey.userName) private var userName = ""
    @AppStorage(PrefKey.companyName) private var companyName = ""

    @State private var page = 0

    private struct Slide {
        let symbol: String
        let accentSymbol: String
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        Slide(symbol: "house.fill", accentSymbol: "key.horizontal.fill", title: "Protect every deposit", body: "Clerk-quality check-in and check-out reports from your iPhone, in minutes instead of hours."),
        Slide(symbol: "camera.fill", accentSymbol: "sparkles", title: "Photograph. AI writes.", body: "Walk each room with your camera. Handover describes every item in the wording inventory clerks use, and you approve it."),
        Slide(symbol: "rectangle.on.rectangle.angled", accentSymbol: "checkmark.seal.fill", title: "Compare and claim", body: "At check-out, line up new photos over the old ones, spot what changed, and export a deposit claim backed by tamper-evident evidence.")
    ]

    var body: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()
            Circle()
                .fill(Theme.gold.opacity(0.15))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: 140, y: -300)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        slideView(slide).tag(index)
                    }
                    setupView.tag(slides.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                pageDots
                    .padding(.bottom, 18)

                Button {
                    if page < slides.count {
                        withAnimation { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < slides.count ? "Continue" : "Get started")
                        .font(.headline)
                        .foregroundStyle(Theme.deepGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 150, height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: slide.symbol)
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(.white)
                    )
                Image(systemName: slide.accentSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.deepGreen)
                    .frame(width: 54, height: 54)
                    .background(Theme.gold, in: Circle())
                    .offset(x: 16, y: 16)
            }
            .padding(.bottom, 30)
            Text(slide.title)
                .font(.display(38, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(slide.body)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Make it yours")
                    .font(.display(34, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 60)
                Text("Your details appear on every report. You can change them later in Settings.")
                    .foregroundStyle(.white.opacity(0.75))

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHERE DO YOU LET PROPERTY?")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Region.allCases) { region in
                            Button {
                                regionRaw = region.rawValue
                                Haptics.tap()
                            } label: {
                                HStack {
                                    Text(region.flag)
                                    Text(region.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(regionRaw == region.rawValue ? Theme.gold.opacity(0.3) : .white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(regionRaw == region.rawValue ? Theme.gold : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NAME")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    TextField("", text: $userName, prompt: Text("e.g. Alex Morgan").foregroundStyle(.white.opacity(0.4)))
                        .textContentType(.name)
                        .padding(14)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("COMPANY (OPTIONAL)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    TextField("", text: $companyName, prompt: Text("e.g. Morgan Lettings").foregroundStyle(.white.opacity(0.4)))
                        .textContentType(.organizationName)
                        .padding(14)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0...slides.count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.gold : .white.opacity(0.3))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: PrefKey.tagLocation)
        Haptics.success()
        withAnimation { hasOnboarded = true }
    }
}
