import SwiftUI

struct UserGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("User Guide")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Getting Started")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("TwinPixCleaner helps you find and remove duplicate images to free up disk space.")
                        
                        Text("Scanning Modes")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Exact Match (Default)")
                                .font(.headline)
                            Text("Finds files that are bit-for-bit identical. Safe to delete any copy.")
                            
                            Text("2. Visual Similarity")
                                .font(.headline)
                            Text("Finds images that look similar but may have differences (size, format, edits).")
                        }
                        .padding(.leading)
                    }
                    
                    Group {
                        Text("How to Scan")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("1. Click 'Select Folder to Scan' or drag & drop a folder.")
                        Text("2. Wait for the scan to complete.")
                        Text("3. Review the results.")
                        
                        Text("Reviewing & Deleting")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("• Select files to delete by clicking them.")
                        Text("• Use Multi-select by clicking multiple files.")
                        Text("• Press Spacebar to preview an image.")
                        Text("• Press Delete key to remove selected files.")
                    }
                    
                    Group {
                        Text("Tips")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("• Always check the file path before deleting.")
                        Text("• Use 'Exact Match' for safe, automated cleanup.")
                        Text("• Use 'Visual Similarity' to find edited copies.")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 600, height: 500)
    }
}
