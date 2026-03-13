import SwiftUI
import AVFoundation

// MARK: - Camera Manager

@Observable
@MainActor
final class LocketCameraManager: NSObject {
    var isSessionRunning = false
    var capturedImage: UIImage?
    var isFrontCamera = true
    var flashEnabled = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?

    func setupSession() {
        guard !isSessionRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

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

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Locket Camera View

struct LocketCameraView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    @State private var camera = LocketCameraManager()
    @State private var shutterScale: CGFloat = 1.0
    @State private var showFlash = false

    private var cameraSize: CGFloat {
        UIScreen.main.bounds.width - 32
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer().frame(height: 16)

                // Camera preview or captured photo
                ZStack {
                    if let image = camera.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cameraSize, height: cameraSize)
                            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        CameraPreviewView(session: camera.session)
                            .frame(width: cameraSize, height: cameraSize)
                            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))

                        if showFlash {
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .fill(.white)
                                .frame(width: cameraSize, height: cameraSize)
                                .transition(.opacity)
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: camera.capturedImage != nil)

                Spacer().frame(height: 24)

                if camera.capturedImage != nil {
                    capturedControls
                } else {
                    cameraControls
                }

                Spacer()
            }
        }
        .onAppear { camera.setupSession() }
        .onDisappear { camera.stopSession() }
        .statusBarHidden()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.15)))
            }

            Spacer()

            Text("Check-in")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if camera.capturedImage == nil {
                Button {
                    camera.flashEnabled.toggle()
                } label: {
                    Image(systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(camera.flashEnabled ? Theme.Colors.warmYellow : .white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.15)))
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - Camera Controls

    private var cameraControls: some View {
        HStack(spacing: 40) {
            Color.clear.frame(width: 50, height: 50)

            // Shutter
            Button {
                withAnimation(.easeIn(duration: 0.1)) {
                    shutterScale = 0.85
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
                        .fill(.white)
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(.white.opacity(0.4), lineWidth: 4)
                        .frame(width: 88, height: 88)
                }
                .scaleEffect(shutterScale)
            }

            // Flip
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    camera.flipCamera()
                }
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
        }
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
                        .background(Circle().fill(.white.opacity(0.15)))
                    Text("Chụp lại")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Button {
                guard let image = camera.capturedImage,
                      let data = image.jpegData(compressionQuality: 0.6) else { return }
                onCapture(data)
                dismiss()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(Theme.Colors.mintGreen.gradient)
                                .shadow(color: Theme.Colors.mintGreen.opacity(0.5), radius: 12, y: 4)
                        )
                    Text("Gửi")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.mintGreen)
                }
            }

            Color.clear.frame(width: 56, height: 76)
        }
    }
}
