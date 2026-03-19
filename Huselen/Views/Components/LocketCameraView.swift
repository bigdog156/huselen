import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Camera Manager

@Observable
@MainActor
final class LocketCameraManager: NSObject {
    var isSessionRunning = false
    var capturedImage: UIImage?
    var isFrontCamera: Bool = true
    var flashEnabled = false
    var permissionDenied = false

    init(isFrontCamera: Bool = true) {
        self.isFrontCamera = isFrontCamera
    }

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

    /// Crops a UIImage to a centered square.
    private static func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let side = min(w, h)
        let x = (w - side) / 2
        let y = (h - side) / 2
        let cropRect = CGRect(x: x, y: y, width: side, height: side)
        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
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
            // Auto-crop to square (1:1)
            image = LocketCameraManager.cropToSquare(image)
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

    private let previewCornerRadius: CGFloat = 32

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
                                .background(Circle().fill(.white.opacity(0.12)))
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
                    HStack(spacing: 40) {
                        Button { onCancel() } label: {
                            Text("Huỷ")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 80, height: 50)
                                .background(
                                    Capsule().fill(.white.opacity(0.12))
                                )
                        }

                        Button {
                            let cropped = performCrop(cropSize: cropSize)
                            onCrop(cropped)
                        } label: {
                            Text("Xong")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 120, height: 50)
                                .background(
                                    Capsule()
                                        .fill(Color.fitGreen)
                                        .shadow(color: Color.fitGreen.opacity(0.4), radius: 12, y: 4)
                                )
                        }
                    }

                    Spacer().frame(height: geo.safeAreaInsets.bottom + 20)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private func clampOffset(cropSize: CGFloat) {
        let imgSize = image.size
        let aspect = imgSize.width / imgSize.height

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

        let displayW: CGFloat
        let displayH: CGFloat
        if aspect > 1 {
            displayH = cropSize * scale
            displayW = displayH * aspect
        } else {
            displayW = cropSize * scale
            displayH = displayW / aspect
        }

        let ratioX = imgSize.width / displayW
        let ratioY = imgSize.height / displayH

        let centerX = displayW / 2 - offset.width
        let centerY = displayH / 2 - offset.height

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
    let useBackCamera: Bool

    init(title: String = "Check-in", useBackCamera: Bool = false, onCapture: @escaping (Data) -> Void) {
        self.title = title
        self.useBackCamera = useBackCamera
        self.onCapture = onCapture
        self._camera = State(initialValue: LocketCameraManager(isFrontCamera: !useBackCamera))
    }

    @State private var camera: LocketCameraManager
    @State private var shutterScale: CGFloat = 1.0
    @State private var showFlash = false
    @State private var flipRotation: Double = 0

    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showCropView = false

    private let previewCornerRadius: CGFloat = 32

    var body: some View {
        ZStack {
            cameraBody

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
            let screenW = geo.size.width
            let previewSize = screenW - 16  // 1:1 square

            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.08, blue: 0.10),
                             Color(red: 0.04, green: 0.04, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, geo.safeAreaInsets.top + 4)
                        .padding(.bottom, 8)

                    // Camera preview — 1:1 square
                    ZStack {
                        if camera.permissionDenied {
                            permissionDeniedView(width: previewSize, height: previewSize)
                        } else if let image = camera.capturedImage {
                            // Captured photo (already cropped to square)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: previewSize, height: previewSize)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        } else {
                            // Live preview
                            CameraPreviewView(session: camera.session)
                                .frame(width: previewSize, height: previewSize)
                                .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))

                            // Flash & flip overlay on preview
                            previewOverlay(width: previewSize, height: previewSize)

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

                    Spacer(minLength: 12)

                    // Bottom controls
                    if camera.capturedImage != nil {
                        capturedControls
                    } else {
                        cameraControls
                    }

                    Spacer().frame(height: geo.safeAreaInsets.bottom + 12)
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
            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.12)))
            }

            Spacer()

            // Title pill
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.1)))

            Spacer()

            // Flash toggle (only when not captured)
            if camera.capturedImage == nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        camera.flashEnabled.toggle()
                    }
                } label: {
                    Image(systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(camera.flashEnabled ? Color(red: 1.0, green: 0.82, blue: 0.2) : .white.opacity(0.6))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(camera.flashEnabled ? Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.15) : .white.opacity(0.12))
                        )
                }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
    }

    // MARK: - Preview Overlay (flash & flip on the preview image)

    private func previewOverlay(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                // Flip camera button on preview
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        camera.flipCamera()
                        flipRotation += 180
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.ultraThinMaterial).opacity(0.8))
                        .rotationEffect(.degrees(flipRotation))
                }
                .padding(16)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Camera Controls (live preview state)

    private var cameraControls: some View {
        HStack(alignment: .center, spacing: 0) {
            // Gallery picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    Text("Thư viện")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)

            // Shutter button
            Button {
                withAnimation(.easeIn(duration: 0.08)) {
                    shutterScale = 0.88
                    showFlash = true
                }
                camera.capturePhoto()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        shutterScale = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.15)) {
                        showFlash = false
                    }
                }
            } label: {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 78, height: 78)

                    // Inner circle
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .white.opacity(0.2), radius: 8, y: 0)
                }
                .scaleEffect(shutterScale)
            }
            .frame(maxWidth: .infinity)

            // Flip camera
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    camera.flipCamera()
                    flipRotation += 180
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .rotationEffect(.degrees(flipRotation))
                    Text("Lật")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Captured Controls (after photo taken)

    private var capturedControls: some View {
        VStack(spacing: 12) {
            // Primary action — Send
            Button {
                guard let image = camera.capturedImage,
                      let data = image.jpegData(compressionQuality: 0.6) else { return }
                onCapture(data)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("Sử dụng ảnh này")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.fitGreen)
                        .shadow(color: Color.fitGreen.opacity(0.3), radius: 12, y: 4)
                )
            }

            // Secondary action — Retake
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    camera.retake()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Chụp lại")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Permission Denied

    private func permissionDeniedView(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Cần quyền truy cập Camera")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text("Vào Cài đặt > Huselen > Bật Camera")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Mở Cài đặt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.fitGreen))
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
}
