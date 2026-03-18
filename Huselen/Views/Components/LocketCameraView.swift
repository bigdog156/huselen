import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Camera Manager

@Observable
@MainActor
final class LocketCameraManager: NSObject {
    var isSessionRunning = false
    var capturedImage: UIImage?
    var isFrontCamera = true
    var flashEnabled = false
    var permissionDenied = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?

    func setupSession() {
        guard !isSessionRunning else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    configureAndStart()
                } else {
                    permissionDenied = true
                }
            }
        default:
            permissionDenied = true
        }
    }

    private func configureAndStart() {
        session.beginConfiguration()
        session.sessionPreset = .high

        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if let existing = currentInput {
            session.removeInput(existing)
        }
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        if session.outputs.isEmpty, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        Task.detached { [session] in
            session.startRunning()
            await MainActor.run { self.isSessionRunning = true }
        }
    }

    func stopSession() {
        Task.detached { [session] in
            session.stopRunning()
            await MainActor.run { self.isSessionRunning = false }
        }
    }

    func flipCamera() {
        isFrontCamera.toggle()
        session.beginConfiguration()

        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if let existing = currentInput {
            session.removeInput(existing)
        }
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        session.commitConfiguration()
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if let device = currentInput?.device, device.hasFlash {
            settings.flashMode = flashEnabled ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func retake() {
        capturedImage = nil
    }
}

extension LocketCameraManager: @preconcurrency AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              var image = UIImage(data: data) else { return }

        Task { @MainActor [weak self] in
            if self?.isFrontCamera == true, let cgImage = image.cgImage {
                image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
            }
            self?.capturedImage = image
        }
    }
}

// MARK: - Camera Preview UIView

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer?.session = session
    }
}

// MARK: - Square Crop View

struct SquareCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let previewCornerRadius: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let cropSize = geo.size.width

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        Button { onCancel() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(.black.opacity(0.35)))
                        }
                        Spacer()
                        Text("Di chuyển & thu phóng")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Color.clear.frame(width: 42, height: 42)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.bottom, 12)

                    // Crop area
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: cropSize, height: cropSize)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                            .gesture(
                                SimultaneousGesture(
                                    MagnifyGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value.magnification
                                            scale = max(1.0, min(newScale, 5.0))
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            clampOffset(cropSize: cropSize)
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            clampOffset(cropSize: cropSize)
                                            lastOffset = offset
                                        }
                                )
                            )
                    }
                    .frame(width: cropSize, height: cropSize)

                    Spacer()

                    // Bottom controls
                    HStack(spacing: 50) {
                        Button { onCancel() } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(.white.opacity(0.12)))
                                Text("Huỷ")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }

                        Button {
                            let cropped = performCrop(cropSize: cropSize)
                            onCrop(cropped)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 64, height: 64)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 1.0, green: 0.82, blue: 0.2),
                                                        Color(red: 0.95, green: 0.7, blue: 0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.5), radius: 12, y: 4)
                                    )
                                Text("Xong")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.2))
                            }
                        }

                        Color.clear.frame(width: 56, height: 76)
                    }

                    Spacer().frame(height: geo.safeAreaInsets.bottom + 16)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private func clampOffset(cropSize: CGFloat) {
        let imgSize = image.size
        let aspect = imgSize.width / imgSize.height

        // Size of image as displayed (scaledToFill in square)
        let displayW: CGFloat
        let displayH: CGFloat
        if aspect > 1 {
            displayH = cropSize * scale
            displayW = displayH * aspect
        } else {
            displayW = cropSize * scale
            displayH = displayW / aspect
        }

        let maxOffsetX = max(0, (displayW - cropSize) / 2)
        let maxOffsetY = max(0, (displayH - cropSize) / 2)

        withAnimation(.easeOut(duration: 0.2)) {
            offset.width = min(maxOffsetX, max(-maxOffsetX, offset.width))
            offset.height = min(maxOffsetY, max(-maxOffsetY, offset.height))
        }
    }

    private func performCrop(cropSize: CGFloat) -> UIImage {
        let imgSize = image.size
        let aspect = imgSize.width / imgSize.height

        // How the image is displayed (scaledToFill in the square)
        let displayW: CGFloat
        let displayH: CGFloat
        if aspect > 1 {
            displayH = cropSize * scale
            displayW = displayH * aspect
        } else {
            displayW = cropSize * scale
            displayH = displayW / aspect
        }

        // Ratio from display to actual image pixels
        let ratioX = imgSize.width / displayW
        let ratioY = imgSize.height / displayH

        // The visible crop window center in display coords
        let centerX = displayW / 2 - offset.width
        let centerY = displayH / 2 - offset.height

        // Convert to image pixel coords
        let cropX = (centerX - cropSize / 2) * ratioX
        let cropY = (centerY - cropSize / 2) * ratioY
        let cropW = cropSize * ratioX
        let cropH = cropSize * ratioY

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            .intersection(CGRect(origin: .zero, size: imgSize))

        guard !cropRect.isEmpty,
              let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
}

// MARK: - Locket Camera View

struct LocketCameraView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onCapture: (Data) -> Void

    init(title: String = "Check-in", onCapture: @escaping (Data) -> Void) {
        self.title = title
        self.onCapture = onCapture
    }

    @State private var camera = LocketCameraManager()
    @State private var shutterScale: CGFloat = 1.0
    @State private var showFlash = false
    @State private var flipRotation: Double = 0

    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showCropView = false

    private let previewCornerRadius: CGFloat = 44

    var body: some View {
        ZStack {
            // Main camera UI
            cameraBody

            // Crop overlay for gallery picks
            if showCropView, let image = pickedImage {
                SquareCropView(
                    image: image,
                    onCrop: { cropped in
                        camera.capturedImage = cropped
                        showCropView = false
                        pickedImage = nil
                    },
                    onCancel: {
                        showCropView = false
                        pickedImage = nil
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCropView)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    pickedImage = uiImage
                    showCropView = true
                }
                selectedPhoto = nil
            }
        }
    }

    // MARK: - Camera Body

    private var cameraBody: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let previewSize = screenWidth

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, geo.safeAreaInsets.top + 8)
                        .padding(.bottom, 12)

                    // Camera preview — 1:1 square, edge-to-edge width
                    ZStack {
                        if camera.permissionDenied {
                            permissionDeniedView(size: previewSize)
                        } else if let image = camera.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: previewSize, height: previewSize)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            CameraPreviewView(session: camera.session)
                                .frame(width: previewSize, height: previewSize)
                                .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))

                            overlayControls(size: previewSize)

                            if showFlash {
                                RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                                    .fill(.white)
                                    .frame(width: previewSize, height: previewSize)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .frame(width: previewSize, height: previewSize)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: camera.capturedImage != nil)

                    Spacer()

                    if camera.capturedImage != nil {
                        capturedControls
                    } else {
                        cameraControls
                    }

                    Spacer().frame(height: geo.safeAreaInsets.bottom + 16)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { camera.setupSession() }
        .onDisappear { camera.stopSession() }
        .statusBarHidden()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.black.opacity(0.35)))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.35)))

            Spacer()

            Color.clear.frame(width: 42, height: 42)
        }
    }

    // MARK: - Overlay Controls

    private func overlayControls(size: CGFloat) -> some View {
        VStack {
            Spacer()

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        camera.flashEnabled.toggle()
                    }
                } label: {
                    Image(systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(camera.flashEnabled ? Color(red: 1.0, green: 0.82, blue: 0.2) : .white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.black.opacity(0.35)))
                }

                Spacer()

                Text("1×")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Camera Controls

    private var cameraControls: some View {
        HStack(alignment: .center) {
            // Photo library picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }

            Spacer()

            // Shutter
            Button {
                withAnimation(.easeIn(duration: 0.1)) {
                    shutterScale = 0.88
                    showFlash = true
                }
                camera.capturePhoto()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        shutterScale = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        showFlash = false
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.82, blue: 0.2),
                                    Color(red: 0.95, green: 0.7, blue: 0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 82, height: 82)

                    Circle()
                        .fill(.white)
                        .frame(width: 68, height: 68)
                }
                .scaleEffect(shutterScale)
            }

            Spacer()

            // Flip camera
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    camera.flipCamera()
                    flipRotation += 180
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(.white.opacity(0.12)))
                    .rotationEffect(.degrees(flipRotation))
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Captured Controls

    private var capturedControls: some View {
        HStack(spacing: 50) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    camera.retake()
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(.white.opacity(0.12)))
                    Text("Chụp lại")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Button {
                guard let image = camera.capturedImage,
                      let data = image.jpegData(compressionQuality: 0.6) else { return }
                onCapture(data)
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.82, blue: 0.2),
                                            Color(red: 0.95, green: 0.7, blue: 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.5), radius: 12, y: 4)
                        )
                    Text("Gửi")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.2))
                }
            }

            Color.clear.frame(width: 56, height: 76)
        }
    }

    // MARK: - Permission Denied

    private func permissionDeniedView(size: CGFloat) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text("Cần quyền truy cập Camera")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text("Vào Cài đặt → Huselen → Bật Camera")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Mở Cài đặt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }
}
