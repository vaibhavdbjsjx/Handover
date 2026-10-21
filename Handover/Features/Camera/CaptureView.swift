import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation

struct CapturedPhoto {
    let image: UIImage
    let capturedAt: Date
    let location: CLLocation?
    var isImported = false
}

enum EvidenceCapture {
    /// Saves a captured image to disk, hashes it and inserts the record.
    @discardableResult
    static func store(_ capture: CapturedPhoto, in context: ModelContext) -> EvidencePhoto? {
        guard let saved = PhotoStore.shared.save(capture.image) else { return nil }
        let photo = EvidencePhoto(
            filename: saved.filename,
            capturedAt: capture.capturedAt,
            sha256: saved.sha256,
            latitude: capture.location?.coordinate.latitude,
            longitude: capture.location?.coordinate.longitude,
            isImported: capture.isImported
        )
        context.insert(photo)
        return photo
    }
}

// MARK: - Camera controller

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "co.handover.camera")
    private var isConfigured = false

    @Published var isUnavailable = false
    @Published var permissionDenied = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off

    var onPhoto: ((UIImage) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndRun()
                } else {
                    DispatchQueue.main.async { self?.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    DispatchQueue.main.async { self.isUnavailable = true }
                    return
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if self.session.canAddInput(input) { self.session.addInput(input) }
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                    self.output.maxPhotoQualityPrioritization = .balanced
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
        }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        settings.photoQualityPrioritization = .balanced
        if let connection = output.connection(with: .video) {
            let angle = Self.rotationAngle(for: UIDevice.current.orientation)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private static func rotationAngle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onPhoto?(image)
        }
    }
}

// MARK: - Preview

private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

// MARK: - Capture screen

struct CaptureView: View {
    let title: String
    /// A baseline photo shown semi-transparent so the new photo can be lined up.
    let overlayFilename: String?
    let onCapture: (CapturedPhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var lastImage: UIImage?
    @State private var count = 0
    @State private var flashOpacity = 0.0
    @State private var showOverlay = true
    @State private var overlayOpacity = 0.35
    @State private var overlayImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permissionDenied {
                permissionMessage
            } else if camera.isUnavailable {
                unavailableMessage
            } else {
                GeometryReader { proxy in
                    ZStack {
                        CameraPreview(session: camera.session)
                        if showOverlay, let overlayImage {
                            Image(uiImage: overlayImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .opacity(overlayOpacity)
                                .allowsHitTesting(false)
                        }
                        gridLines
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.top, 60)
                .padding(.bottom, 150)
                .ignoresSafeArea(edges: .bottom)
            }

            Color.white.opacity(flashOpacity).ignoresSafeArea().allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                if overlayImage != nil && showOverlay {
                    HStack(spacing: 10) {
                        Image(systemName: "square.on.square.dashed")
                        Slider(value: $overlayOpacity, in: 0.1...0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 8)
                }
                bottomBar
            }
        }
        .statusBarHidden()
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            LocationProvider.shared.start()
            camera.onPhoto = handle
            camera.start()
            if let overlayFilename {
                overlayImage = PhotoStore.shared.image(overlayFilename)
            }
        }
        .onDisappear {
            camera.stop()
            LocationProvider.shared.stop()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if overlayImage != nil {
                Button { showOverlay.toggle() } label: {
                    Image(systemName: showOverlay ? "square.on.square.dashed" : "square.dashed")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Toggle check-in overlay")
            }
            Button {
                camera.flashMode = camera.flashMode == .off ? .on : (camera.flashMode == .on ? .auto : .off)
            } label: {
                Image(systemName: flashSymbol)
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Flash")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var flashSymbol: String {
        switch camera.flashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        default: return "bolt.slash.fill"
        }
    }

    private var bottomBar: some View {
        HStack {
            ZStack {
                if let lastImage {
                    Image(uiImage: lastImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Text("\(count)")
                                .font(.caption2.weight(.bold))
                                .padding(5)
                                .background(Theme.gold, in: Circle())
                                .foregroundStyle(.black)
                                .offset(x: 8, y: -8)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 54, height: 54)
                }
            }
            .frame(width: 80)

            Spacer()

            Button(action: shoot) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 64, height: 64)
                }
            }
            .accessibilityLabel("Take photo")
            .disabled(camera.permissionDenied || camera.isUnavailable)

            Spacer()

            Button { dismiss() } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.gold, in: Capsule())
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    private var gridLines: some View {
        GeometryReader { proxy in
            Path { path in
                for i in 1...2 {
                    let x = proxy.size.width * CGFloat(i) / 3
                    let y = proxy.size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.18), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private var permissionMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text("Camera access is off").font(.title3.weight(.semibold))
            Text("Allow camera access in Settings to photograph rooms for your report.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(40)
    }

    private var unavailableMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown").font(.largeTitle)
            Text("No camera available").font(.title3.weight(.semibold))
            Text("Use \"Add from library\" instead, or run Handover on an iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(40)
    }

    private func shoot() {
        Haptics.shutter()
        withAnimation(.easeOut(duration: 0.05)) { flashOpacity = 0.8 }
        withAnimation(.easeIn(duration: 0.25).delay(0.05)) { flashOpacity = 0 }
        camera.capture()
    }

    private func handle(_ image: UIImage) {
        let capture = CapturedPhoto(image: image, capturedAt: .now, location: LocationProvider.shared.freshLocation)
        onCapture(capture)
        lastImage = image
        count += 1
    }
}
