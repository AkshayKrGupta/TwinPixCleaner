import SwiftUI
import Photos

struct UniversalImageView: View {
    let url: URL
    
    @State private var image: Image?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var loadTask: Task<Void, Never>?
    @State private var photoRequestID: PHImageRequestID?
    
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if hasError {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary)
                    Text("Unable to load")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancelLoading()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        if let requestID = photoRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            photoRequestID = nil
        }
        isLoading = false
    }

    private func loadImage() {
        cancelLoading()
        isLoading = true
        hasError = false
        image = nil
        
        if url.scheme == "photos" {
            loadPhotoAsset()
        } else {
            loadFileAsset()
        }
    }
    
    private func loadFileAsset() {
        loadTask = Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 400,        // matches the Photos path's 400x400 target
                kCGImageSourceCreateThumbnailWithTransform: true // respect EXIF orientation
            ]
            guard !Task.isCancelled,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.hasError = true
                        self.isLoading = false
                    }
                }
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.image = Image(decorative: thumbnail, scale: 1.0)
                self.isLoading = false
            }
        }
    }
    
    private func loadPhotoAsset() {
        guard let asset = PhotosAssetURL.asset(from: url) else {
            self.hasError = true
            self.isLoading = false
            return
        }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        photoRequestID = manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 400),
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            DispatchQueue.main.async {
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if isCancelled { return }
                if let nsImage = result {
                    self.image = Image(nsImage: nsImage)
                } else {
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded {
                        self.hasError = true
                    }
                }
                self.isLoading = false
            }
        }
    }
}
