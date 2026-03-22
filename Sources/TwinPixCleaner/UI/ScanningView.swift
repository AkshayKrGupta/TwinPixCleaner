import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(FrostTheme.accentGradient)
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
            VStack(spacing: 12) {
                ProgressView(value: viewModel.scanProgress, total: 1.0)
                    .frame(width: 360)
                    .tint(.indigo)
                
                Text("\(Int(viewModel.scanProgress * 100))% Complete")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .frostCard(cornerRadius: 20)
            
            // Cancel Button
            Button(action: {
                viewModel.cancelScanning()
            }) {
                Text("Cancel Scan")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background is handled by App root container
    }
}
