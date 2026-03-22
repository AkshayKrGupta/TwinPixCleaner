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
                Text(AppConstants.Strings.scanningTitle)
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
                Text(AppConstants.Strings.cancelScan)
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.frostSecondary)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background is handled by App root container
    }
}
