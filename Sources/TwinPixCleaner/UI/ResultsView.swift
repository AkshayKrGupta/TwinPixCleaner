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
            // Subtle background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if groups.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.green)
                            .symbolRenderingMode(.hierarchical)
                        
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
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                            
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
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            
                            // Actions
                            HStack(spacing: 12) {
                                if !viewModel.selectedFiles.isEmpty {
                                    Button(role: .destructive) {
                                        viewModel.deleteSelectedFiles()
                                    } label: {
                                        Label("Delete \(viewModel.selectedFiles.count)", systemImage: "trash")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
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

struct DuplicateGroupRow: View {
    @ObservedObject var viewModel: AppViewModel
    let group: DuplicateGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text("Duplicate Set")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file), systemImage: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Label("\(group.fileURLs.count) copies", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Images
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.fileURLs, id: \.self) { url in
                        DuplicateItemView(
                            url: url,
                            isSelected: viewModel.selectedFiles.contains(url),
                            metadata: viewModel.getFileMetadata(url: url),
                            onToggleSelection: { viewModel.toggleSelection(for: url) },
                            onDelete: { viewModel.deleteFile(url: url, in: group) }
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

struct DuplicateItemView: View {
    let url: URL
    let isSelected: Bool
    let metadata: String
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        ZStack {
                            Color(nsColor: .controlBackgroundColor)
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.secondary)
                                Text("Unable to load")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        ZStack {
                            Color(nsColor: .controlBackgroundColor)
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .frame(width: 200, height: 200)
                .clipped()
                
                // Selection Checkbox
                Button(action: onToggleSelection) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? .blue : .white)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .padding(8)
                
                // Hover Overlay
                if isHovering {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metadata)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white)
                            .lineSpacing(2)
                            .padding(10)
                    }
                    .background(.ultraThickMaterial)
                    .environment(\.colorScheme, .dark)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                    .padding(8)
                    .frame(maxWidth: 200, alignment: .leading)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .allowsHitTesting(false)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .onTapGesture {
                onToggleSelection()
            }
            
            // Info Section with Better Contrast
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(url.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
                
                Divider()
                
                // Delete Button
                Button(action: onDelete) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                        Text("Move to Trash")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .background(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.5 : 0))
            }
            .frame(width: 200)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.08),
            radius: isSelected ? 8 : 3,
            y: isSelected ? 4 : 1
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

