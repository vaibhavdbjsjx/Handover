import SwiftUI
import SwiftData
import PDFKit

struct ReportPreviewView: View {
    let inspection: Inspection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store

    @State private var output: ReportRenderer.Output?
    @State private var isRendering = true
    @State private var renderError: String?
    @State private var showingShare = false
    @State private var showingPaywall = false
    @State private var renderedWithWatermark = false

    private var canExport: Bool { store.canExport(inspection) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGray5).ignoresSafeArea()
                if let output {
                    PDFKitView(url: output.url, token: output.sha256)
                        .ignoresSafeArea(edges: .bottom)
                } else if let renderError {
                    EmptyStateView(symbol: "exclamationmark.triangle", title: "Couldn't build the report", message: renderError, actionTitle: "Try again") {
                        render()
                    }
                }
                if isRendering {
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.large)
                        Text("Building your report…")
                            .font(.headline)
                        Text("Laying out \(inspection.photoCount) photos")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .navigationTitle(inspection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let output {
                    ToolbarItem(placement: .principal) {
                        Text("\(output.pageCount) pages")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showingShare) {
                if let output { ShareSheet(items: [output.url]) }
            }
            .sheet(isPresented: $showingPaywall, onDismiss: {
                if canExport && renderedWithWatermark { render() }
            }) {
                PaywallView(reason: .export)
            }
            .task { render() }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if output != nil && !isRendering {
            VStack(spacing: 8) {
                if canExport {
                    if inspection.status == .draft {
                        Label("This report isn't signed yet. Sign and finalise it before sending it as evidence.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: share) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.primary)
                } else if store.reportCredits > 0 {
                    Button {
                        if store.spendCredit(on: inspection) {
                            try? context.save()
                            render()
                        }
                    } label: {
                        Label("Use 1 report credit (\(store.reportCredits) left)", systemImage: "ticket.fill")
                    }
                    .buttonStyle(.primary)
                } else {
                    Text("You're viewing a watermarked preview.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button { showingPaywall = true } label: {
                        Label("Unlock export", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(.bar)
        }
    }

    private func render() {
        isRendering = true
        renderError = nil
        let watermark = !canExport
        renderedWithWatermark = watermark
        let snapshot = ReportSnapshot(inspection: inspection)
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try ReportRenderer(snapshot: snapshot, watermark: watermark).render()
                }.value
                output = result
            } catch {
                renderError = "Something went wrong while creating the PDF. Please try again."
            }
            isRendering = false
        }
    }

    private func share() {
        guard let output else { return }
        store.consumeExport(for: inspection)
        inspection.exportCount += 1
        inspection.lastExportHash = output.sha256
        try? context.save()
        showingShare = true
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    /// Changes whenever the file is re-rendered, so the view reloads.
    let token: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = .systemGray5
        view.document = PDFDocument(url: url)
        context.coordinator.token = token
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        guard context.coordinator.token != token else { return }
        context.coordinator.token = token
        uiView.document = PDFDocument(url: url)
    }

    final class Coordinator {
        var token = ""
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
