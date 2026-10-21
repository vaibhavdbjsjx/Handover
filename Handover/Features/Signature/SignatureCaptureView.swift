import SwiftUI
import SwiftData
import PencilKit

struct SignatureCaptureView: View {
    let inspection: Inspection

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var role: SignatureRole = .tenant
    @State private var name = ""
    @State private var canvas = PKCanvasView()
    @State private var hasInk = false
    @State private var agreed = false

    private var statement: String {
        let region = inspection.region
        switch inspection.kind {
        case .checkIn:
            return "I confirm that I have reviewed this \(region.reportTitle(for: .checkIn).lowercased()), including its photographs, and that it is a fair record of the property's condition and contents on \(inspection.date.formatted(date: .long, time: .omitted)), subject to any comments noted."
        case .checkOut:
            return "I confirm that I have reviewed this \(region.reportTitle(for: .checkOut).lowercased()), including its photographs, and that it is a fair record of the property's condition on \(inspection.date.formatted(date: .long, time: .omitted)), subject to any comments noted. Signing does not mean I agree to any proposed deductions."
        case .interim:
            return "I confirm that this interim inspection was carried out on \(inspection.date.formatted(date: .long, time: .omitted)) and that it is a fair record of what was seen, subject to any comments noted."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Signing as", selection: $role) {
                        ForEach(SignatureRole.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    TextField("Full name", text: $name)
                        .textContentType(.name)
                        .font(.title3)
                        .card()

                    Text(statement)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .card()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sign below").font(.headline)
                            Spacer()
                            Button("Clear") {
                                canvas.drawing = PKDrawing()
                                hasInk = false
                            }
                            .disabled(!hasInk)
                        }
                        SignaturePad(canvas: $canvas, hasInk: $hasInk)
                            .frame(height: 200)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 44)
                                    .allowsHitTesting(false)
                            }
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
                    }

                    Toggle(isOn: $agreed) {
                        Text("I agree with the statement above")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(Theme.accent)

                    Button("Save signature", action: save)
                        .buttonStyle(.primary)
                        .disabled(!canSave)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Sign report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if inspection.signatures.contains(where: { $0.role == .tenant }) {
                    role = .landlord
                    name = inspection.landlordName
                } else {
                    name = inspection.tenantNames
                }
            }
            .onChange(of: role) { _, newRole in
                switch newRole {
                case .tenant: name = inspection.tenantNames
                case .landlord: name = inspection.landlordName
                case .agent: name = inspection.inspectorName
                case .witness: name = ""
                }
            }
        }
        .interactiveDismissDisabled(hasInk)
    }

    private var canSave: Bool {
        hasInk && agreed && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let bounds = canvas.drawing.bounds.insetBy(dx: -12, dy: -12)
        var image = UIImage()
        // Render in light mode so the ink is always black on the PDF.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = canvas.drawing.image(from: bounds, scale: 3)
        }
        guard let saved = PhotoStore.shared.savePNG(image) else { return }
        let record = SignatureRecord(role: role, name: name.trimmingCharacters(in: .whitespaces), imageFilename: saved.filename, statement: statement)
        context.insert(record)
        record.inspection = inspection
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

private struct SignaturePad: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var hasInk: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(hasInk: $hasInk) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var hasInk: Binding<Bool>
        init(hasInk: Binding<Bool>) { self.hasInk = hasInk }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasInk.wrappedValue = !canvasView.drawing.strokes.isEmpty
        }
    }
}

struct AIConsentSheet: View {
    let onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        Circle().fill(Theme.heroGradient).frame(width: 72, height: 72)
                        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Theme.gold)
                    }
                    Text("Before AI reads your photos")
                        .font(.display(28, weight: .bold))
                    consentRow("photo.on.rectangle.angled", "What is sent", "The photos of this room, the room name and the item list. Names, addresses and signatures are never sent.")
                    consentRow("server.rack", "Who processes it", "Handover's server passes them to Google's Gemini AI service to write the descriptions, and returns the result to your phone.")
                    consentRow("trash.slash", "What is kept", "Nothing. Handover's server doesn't store your photos, and they aren't used to train AI models.")
                    consentRow("hand.raised.fill", "Your choice", "You can always write descriptions yourself instead. You can withdraw consent at any time in Settings.")
                    Link("Read the privacy policy", destination: AppConfig.privacyURL)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("Allow and continue", action: onAccept)
                        .buttonStyle(.primary)
                    Button("Not now") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func consentRow(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
