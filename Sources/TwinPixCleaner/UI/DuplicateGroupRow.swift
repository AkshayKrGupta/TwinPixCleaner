import SwiftUI

struct DuplicateGroupRow: View {
    @ObservedObject var viewModel: AppViewModel
    let group: DuplicateGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: AppConstants.Icons.exactMatch) // Changed from square.on.square
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text("Duplicate Set")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file), systemImage: AppConstants.Icons.docText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Label("\(group.fileURLs.count) copies", systemImage: AppConstants.Icons.photoCopies)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        viewModel.selectAllDuplicates(in: group)
                    }) {
                        Label(AppConstants.Strings.selectAllDuplicates, systemImage: AppConstants.Icons.checkmarkCircle)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.frostPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
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
                            onDelete: { viewModel.deleteFile(url: url, in: group) },
                            onKeep: { viewModel.keepOnly(url, in: group) },
                            onPreview: {
                                let idx = group.fileURLs.firstIndex(of: url) ?? 0
                                viewModel.toggleQuickLook(for: group.fileURLs, at: idx)
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
        .frostCard(cornerRadius: AppConstants.UI.cardCornerRadius)
    }
}
