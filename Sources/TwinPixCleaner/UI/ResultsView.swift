import SwiftUI

enum SortOption: String, CaseIterable {
    case largestFirst = "Largest First"
    case smallestFirst = "Smallest First"
    case mostCopies = "Most Copies"
    case fewestCopies = "Fewest Copies"
}

struct ResultsView: View {
    @ObservedObject var viewModel: AppViewModel
    let groups: [DuplicateGroup]
    @State private var sortOption: SortOption = .largestFirst
    @State private var isAnimatingCheckmark = false
    
    var sortedGroups: [DuplicateGroup] {
        switch sortOption {
        case .largestFirst:
            return groups.sorted { $0.fileSize > $1.fileSize }
        case .smallestFirst:
            return groups.sorted { $0.fileSize < $1.fileSize }
        case .mostCopies:
            return groups.sorted { $0.fileURLs.count > $1.fileURLs.count }
        case .fewestCopies:
            return groups.sorted { $0.fileURLs.count < $1.fileURLs.count }
        }
    }
    
    var totalDuplicates: Int {
        groups.reduce(0) { $0 + $1.fileURLs.count }
    }
    
    var totalSize: Int64 {
        groups.reduce(0) { $0 + (Int64($1.fileURLs.count) * $1.fileSize) }
    }
    
    var potentialSavings: Int64 {
        groups.reduce(0) { total, group in
            total + (Int64(group.fileURLs.count - 1) * group.fileSize)
        }
    }
    
    var body: some View {
        ZStack {
            // Background handled by App container
            
            VStack(spacing: 0) {
                if groups.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.green)
                            .symbolRenderingMode(.hierarchical)
                            .scaleEffect(isAnimatingCheckmark ? 1.0 : 0.5)
                            .opacity(isAnimatingCheckmark ? 1.0 : 0.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.5).delay(0.1), value: isAnimatingCheckmark)
                            .onAppear {
                                isAnimatingCheckmark = true
                            }
                        
                        VStack(spacing: 8) {
                            Text("No Duplicates Found")
                                .font(.system(size: 28, weight: .semibold))
                            Text("Your photo library is clean and organized")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Scan Another Folder") {
                            viewModel.reset()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Header
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            // Logo
                            if let iconImage = loadAppIcon() {
                                Image(nsImage: iconImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .shadow(radius: 2)
                            } else {
                                // Fallback to SF Symbol
                                Image(systemName: "photo.stack.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(
                                        FrostTheme.accentGradient
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TwinPixCleaner")
                                    .font(.system(size: 22, weight: .semibold))
                                Text("Duplicate Analysis")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Sort Picker
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Picker("Sort", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                            
                            // Actions
                            HStack(spacing: 12) {
                                if !viewModel.selectedFiles.isEmpty {
                                    Button(action: {
                                        viewModel.deleteSelectedFiles()
                                    }) {
                                        Label("Delete \(viewModel.selectedFiles.count)", systemImage: "trash")
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.frostPrimary)
                                }
                                
                                Button {
                                    viewModel.reset()
                                } label: {
                                    Text("New Scan")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                    }
                    .background(.ultraThinMaterial)
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedGroups) { group in
                                DuplicateGroupRow(viewModel: viewModel, group: group)
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 60) // Space for footer
                    }
                    .focusable()
                    .onDeleteCommand {
                        if !viewModel.selectedFiles.isEmpty {
                            viewModel.deleteSelectedFiles()
                        }
                    }
                    .onAppear {
                        // Ensure the view can receive keyboard events
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    }
                    
                    // Fixed Footer Bar
                    VStack(spacing: 0) {
                        Divider()
                        
                        HStack(spacing: 32) {
                            // Duplicate Groups
                            HStack(spacing: 8) {
                                Image(systemName: "square.on.square.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .symbolRenderingMode(.hierarchical)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(groups.count)")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Duplicate Groups")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                                .frame(height: 24)
                            
                            // Total Files
                            HStack(spacing: 8) {
                                Image(systemName: "photo.fill.on.rectangle.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.purple)
                                    .symbolRenderingMode(.hierarchical)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(totalDuplicates)")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Total Duplicates")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                                .frame(height: 24)
                            
                            // Potential Savings
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.green)
                                    .symbolRenderingMode(.hierarchical)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ByteCountFormatter.string(fromByteCount: potentialSavings, countStyle: .file))
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Can Be Freed")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            ThemeToggle()
                                .controlSize(.mini)
                                .frame(width: 150)
                            
                            // Selection Info
                            if !viewModel.selectedFiles.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.blue)
                                    Text("\(viewModel.selectedFiles.count) selected")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
    }
}



// Helper function to load AppIcon from correct location
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
