import SwiftUI

struct GuideSection<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostCard(cornerRadius: 16)
    }
}

struct UserGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundStyle(FrostTheme.Colors.brand)
                    Text("TwinPixCleaner User Guide")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GuideSection {
                        Text("Getting Started")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("TwinPixCleaner uses Apple Silicon and Vision Intelligence to safely detect duplicate and visually similar photos on your Mac and Apple Photos library.")
                        
                        Text("Scanning Modes")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(FrostTheme.Colors.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Exact Match (Default)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Uses SHA-256 hashing to find bit-for-bit identical files. Safe to delete any duplicate copy.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(FrostTheme.Colors.brandAlt)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Visual Similarity")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Uses Apple Vision ML feature prints to cluster near-identical shots, resized images, and bursts.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    GuideSection {
                        Text("Scanning Sources")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• **Folder Scanning**: Click 'Select Folder to Scan' or drag and drop any folder directly onto the app.")
                            Text("• **Apple Photos Library**: Click 'Scan Apple Photos' to analyze your Photos library without uploading to any external servers.")
                        }
                        .font(.subheadline)
                    }
                    
                    GuideSection {
                        Text("Reviewing, Quick Look & Deletion")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• **Card Selection**: Click any photo thumbnail to toggle it for batch deletion.")
                            Text("• **Keep This**: Click 'Keep This' on a photo to preserve it and automatically select all other copies in that group.")
                            Text("• **Select All Duplicates**: Use the button in each group header to keep the first photo and select all copies.")
                            Text("• **Quick Look Preview**: Press **Spacebar** on any card for an instant, full-resolution preview.")
                            Text("• **Safe Undo**: Made a mistake? Press **⌘Z** or click **'Undo'** on the toast notification to restore trashed files.")
                        }
                        .font(.subheadline)
                    }
                    
                    GuideSection {
                        Text("Skipped Items & iCloud")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• **iCloud Photos**: Photos stored exclusively in iCloud are skipped to protect your internet bandwidth and avoid filling your local disk storage.")
                            Text("• **View Details**: Click 'View Details' on the top banner after a scan to see a categorized breakdown of skipped iCloud items and non-still media.")
                            Text("• **Clear Similarity Cache**: Use **Help ➔ Clear Similarity Cache** in the macOS menu bar to free disk space taken by cached feature prints.")
                        }
                        .font(.subheadline)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 620, height: 520)
        .frostBackground()
    }
}
