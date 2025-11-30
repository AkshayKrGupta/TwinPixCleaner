import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo and Title
            VStack(spacing: 15) {
                if let iconImage = loadAppIcon() {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .shadow(radius: 10)
                } else {
                    // Fallback to SF Symbol if icon not found
                    Image(systemName: "photo.stack")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text("TwinPixCleaner")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Smart Duplicate Photo Finder")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // About Section
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Find exact duplicate images across your Mac")
                        .font(.body)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Safe deletion - files moved to Trash")
                        .font(.body)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Multi-select for batch operations")
                        .font(.body)
                }
                
              
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // Scan Settings
            VStack(spacing: 16) {
                Picker("Scan Mode", selection: $viewModel.scanMode) {
                    ForEach(ScanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                // Info message for Visual Similarity
                if viewModel.scanMode == .similar {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visual Similarity takes extra time to process.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Consider running Exact Match first for faster results.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(width: 300)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: selectFolder) {
                    Label("Select Folder to Scan", systemImage: "folder.fill.badge.plus")
                        .font(.headline)
                        .padding()
                        .frame(width: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("or drag and drop a folder here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Footer with Developer Info
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ThemeToggle()
                        .frame(width: 120)
                        .controlSize(.small)
                    
                    Button(action: {
                        viewModel.showUserGuide = true
                    }) {
                        Label("User Guide", systemImage: "book.fill")
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
                
                VStack(spacing: 4) {
                Text("© 2025 TwinPixCleaner • Made with ❤️ for macOS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text("Developed by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        if let url = URL(string: "https://www.linkedin.com/in/akshay-kr-gupta/") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Akshay K Gupta")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        viewModel.startScanning(directory: url)
                    }
                }
            }
            return true
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                viewModel.startScanning(directory: url)
            }
        }
    }
    
    private func loadAppIcon() -> NSImage? {
        // Try loading from named asset (works in development with swift run)
        if let image = NSImage(named: "AppIcon") {
            return image
        }
        
        // Try loading from resource bundle (works in packaged .app)
        if let resourceBundle = Bundle.main.url(forResource: "TwinPixCleaner_TwinPixCleaner", withExtension: "bundle"),
           let bundle = Bundle(url: resourceBundle),
           let imagePath = bundle.path(forResource: "AppIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: imagePath) {
            return image
        }
        
        return nil
    }
}
