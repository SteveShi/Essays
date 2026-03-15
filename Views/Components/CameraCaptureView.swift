import SwiftUI
@preconcurrency import AVFoundation

struct CameraCaptureView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var model = CameraModel()
    var onCapture: (Data) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            
            ZStack {
                if let session = model.session {
                    CameraPreview(session: session)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            Text(String(localized: "Initializing Camera...", comment: "Label shown while camera is starting"))
                                .foregroundColor(.white)
                        )
                }
                
                if model.isCapturing {
                    Color.white.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .padding(16)
            
            controls
        }
        #if os(macOS)
        .frame(width: 480, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        #else
        .background(.ultraThinMaterial)
        #endif
        .onAppear {
            model.startSession()
        }
        .onDisappear {
            model.stopSession()
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Take Photo", comment: "Title for camera capture view"))
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var controls: some View {
        HStack {
            Spacer()
            Button {
                model.capturePhoto { data in
                    if let data = data {
                        onCapture(data)
                        dismiss()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 54, height: 54)
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.bottom, 24)
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session: AVCaptureSession?
    @Published var isCapturing = false
    
    private let output = AVCapturePhotoOutput()
    private var captureCompletion: ((Data?) -> Void)?
    
    func startSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        self.session = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func stopSession() {
        session?.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        self.captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        isCapturing = true
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false
        if let error = error {
            print("Error capturing photo: \(error)")
            captureCompletion?(nil)
            return
        }
        
        if let data = photo.fileDataRepresentation() {
            captureCompletion?(data)
        } else {
            captureCompletion?(nil)
        }
    }
}

#if os(macOS)
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.frame = nsView.bounds
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
#else
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
#endif
