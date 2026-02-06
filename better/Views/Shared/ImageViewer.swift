import SwiftUI
import Photos

struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var showingShareSheet = false
    @State private var showingSaveSuccess = false
    @State private var saveErrorMessage: String?
    @State private var showingSaveError = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Image with gestures
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                if newScale >= 1.0 {
                                    scale = newScale
                                }
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                if scale > 1.0 {
                                    lastOffset = offset
                                }
                            }
                    )
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                            }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            // UI Overlay
            VStack {
                // Top bar with close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bottom action bar
                HStack(spacing: 30) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        actionButton(icon: "square.and.arrow.up", text: "Share")
                    }
                    
                    Button {
                        saveToPhotos()
                    } label: {
                        actionButton(icon: "square.and.arrow.down", text: "Save")
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [image])
        }
        .overlay {
            if showingSaveSuccess {
                saveSuccessView
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Unknown error")
        }
        .statusBarHidden()
    }
    
    private func actionButton(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.white)
        .frame(width: 60)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var saveSuccessView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.mint)
            Text("Saved to Photos")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSaveSuccess = false
                }
            }
        }
    }
    
    private func saveToPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            performSave()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    performSave()
                } else {
                    DispatchQueue.main.async {
                        saveErrorMessage = "Please enable photo library access in Settings to save images."
                        showingSaveError = true
                    }
                }
            }
        case .denied, .restricted:
            saveErrorMessage = "Please enable photo library access in Settings to save images."
            showingSaveError = true
        @unknown default:
            break
        }
    }
    
    private func performSave() {
        // Must perform changes on a background queue usually handled by the library, 
        // but performChanges is async.
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation {
                        showingSaveSuccess = true
                    }
                } else {
                    saveErrorMessage = error?.localizedDescription ?? "Failed to save image"
                    showingSaveError = true
                }
            }
        }
    }
}

// Helper for Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
