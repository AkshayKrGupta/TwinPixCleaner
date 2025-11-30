import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 12) {
                Text("Scanning for Duplicates")
                    .font(.system(size: 24, weight: .semibold))
                
                if !viewModel.currentFile.isEmpty {
                    Text(viewModel.currentFile)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 500)
                }
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: viewModel.scanProgress, total: 1.0)
                    .frame(width: 400)
                
                Text("\(Int(viewModel.scanProgress * 100))% Complete")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Cancel Button
            Button("Cancel Scan") {
                viewModel.cancelScanning()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
