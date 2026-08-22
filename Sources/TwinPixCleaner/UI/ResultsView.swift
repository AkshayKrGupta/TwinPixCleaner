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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            VStack(spacing: 0) {
                if viewModel.lastScanSkippedCount > 0 {
                    skippedFilesBanner
                }

                if groups.isEmpty {
                    emptyStateView
                } else {
                    headerBar
                    resultsList
                    footerStatsBar
                }
            }

            if viewModel.showUndoToast {
                VStack {
                    Spacer()
                    undoToast
                        .padding(.bottom, groups.isEmpty ? 24 : 84)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.showUndoToast)
        .sheet(isPresented: $viewModel.showSkippedFilesSheet) {
            SkippedFilesSheetView(summary: viewModel.lastScanSkippedSummary)
        }
    }

    private var undoToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FrostTheme.Colors.success)
            Text("Moved \(viewModel.lastDeletionCount) \(viewModel.lastDeletionCount == 1 ? "file" : "files") to Trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Button("Undo") {
                viewModel.undoLastBatch()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(FrostTheme.accentGradient)
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }

    private var skippedFilesBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(FrostTheme.Colors.brand)
            Text("\(viewModel.lastScanSkippedCount) \(viewModel.lastScanSkippedCount == 1 ? "item" : "items") skipped during scan (iCloud / non-photo items)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                viewModel.showSkippedFilesSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text("View Details")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(FrostTheme.Colors.success)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
                .scaleEffect(reduceMotion ? 1.0 : (isAnimatingCheckmark ? 1.0 : 0.5))
                .opacity(reduceMotion ? 1.0 : (isAnimatingCheckmark ? 1.0 : 0.0))
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.5).delay(0.1), value: isAnimatingCheckmark)
                .onAppear {
                    isAnimatingCheckmark = true
                }

            VStack(spacing: 8) {
                Text(AppConstants.Strings.noDuplicatesFound)
                    .font(.system(size: 28, weight: .semibold))
                Text(AppConstants.Strings.noDuplicatesDesc)
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
    }

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let iconImage = loadAppIcon() {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .shadow(radius: 2)
                } else {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(FrostTheme.accentGradient)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("TwinPixCleaner")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Duplicate Analysis")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

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
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))

                HStack(spacing: 12) {
                    if !viewModel.selectedFiles.isEmpty {
                        Button(action: {
                            viewModel.selectedFiles.removeAll()
                        }) {
                            Text("Clear Selection")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button(action: {
                            viewModel.deleteSelectedFiles()
                        }) {
                            Label("\(AppConstants.Strings.deleteSelected) \(viewModel.selectedFiles.count)", systemImage: AppConstants.Icons.trash)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.frostPrimary)
                    }

                    Button {
                        viewModel.reset()
                    } label: {
                        Text(AppConstants.Strings.newScan)
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
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sortedGroups) { group in
                    DuplicateGroupRow(viewModel: viewModel, group: group)
                }
            }
            .padding(20)
            .padding(.bottom, 60) // Space for the fixed footer bar
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
                NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private var footerStatsBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 32) {
                // Invisible button so Spacebar opens Quick Look even without a visible focus target.
                Button("") {
                    if !viewModel.selectedFiles.isEmpty {
                        viewModel.toggleQuickLook(for: Array(viewModel.selectedFiles))
                    }
                }
                .keyboardShortcut(.space, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)

                StatTile(icon: "square.on.square.fill", tint: FrostTheme.Colors.brand, value: "\(groups.count)", label: "Duplicate Groups")

                Divider().frame(height: 24)

                StatTile(icon: "photo.fill.on.rectangle.fill", tint: FrostTheme.Colors.brandAlt, value: "\(totalDuplicates)", label: "Total Duplicates")

                Divider().frame(height: 24)

                StatTile(
                    icon: "arrow.down.circle.fill",
                    tint: FrostTheme.Colors.success,
                    value: ByteCountFormatter.string(fromByteCount: potentialSavings, countStyle: .file),
                    label: "Can Be Freed"
                )

                Spacer()

                ThemeToggle()
                    .controlSize(.mini)
                    .frame(width: 150)

                if !viewModel.selectedFiles.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(FrostTheme.Colors.brand)
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

/// A small icon + value + label block, used by `footerStatsBar` to show the group/file/savings counts.
private struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
