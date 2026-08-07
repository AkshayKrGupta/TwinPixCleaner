import SwiftUI
import Photos

struct UniversalImageView: View {
    let url: URL
    
    @State private var image: Image?
    @State private var isLoading = false
    @State private var hasError = false
    
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
    }
    
    private func loadImage() {
        guard !isLoading else { return }
        isLoading = true
        
        if url.scheme == "photos" {
            loadPhotoAsset()
        } else {
            loadFileAsset()
        }
    }
    
    private func loadFileAsset() {
        Task {
            if let nsImage = NSImage(contentsOf: url) {
                await MainActor.run {
                    self.image = Image(nsImage: nsImage)
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                }
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
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 400),
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            DispatchQueue.main.async {
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
