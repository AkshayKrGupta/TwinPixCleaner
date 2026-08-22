import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isTargeted = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    logoSection
                    aboutSection
                    actionCard
                    Spacer(minLength: 16)
                    footerSection
                }
                .padding()
                // Fill viewport when tall (footer pinned to bottom); scroll when short.
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    if url.hasDirectoryPath {
                        viewModel.startScanning(directory: url)
                    } else {
                        viewModel.appError = .notAFolder(url)
                    }
                }
            }
            return true
        }
    }

    private var logoSection: some View {
        VStack(spacing: 12) {
            if let iconImage = loadAppIcon() {
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(radius: 8)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: AppConstants.Icons.appIcon)
                    .font(.system(size: 72))
                    .foregroundStyle(FrostTheme.accentGradient)
                    .accessibilityHidden(true)
            }

            Text(AppConstants.Strings.appName)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(FrostTheme.accentGradient)

            Text(AppConstants.Strings.aboutDescription)
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureBullet(text: "Find exact duplicate images across your Mac")
            FeatureBullet(text: "Safe deletion - files moved to Trash")
            FeatureBullet(text: "Multi-select for batch operations")
        }
        .padding(20)
        .frostCard(cornerRadius: 20)
    }

    private var actionCard: some View {
        VStack(spacing: 20) {
            scanModeSection

            Divider()
                .frame(width: 260)

            VStack(spacing: 12) {
                Button(action: selectFolder) {
                    Label(AppConstants.Strings.selectFolder, systemImage: AppConstants.Icons.folderPlus)
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(width: 280)
                }
                .buttonStyle(.frostPrimary)

                Button(action: {
                    viewModel.startPhotosScanning()
                }) {
                    Label("Scan Apple Photos", systemImage: AppConstants.Icons.photoCopies)
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(width: 280)
                }
                .buttonStyle(.frostPrimary)

                Text(AppConstants.Strings.dragDropPrompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .frostCard(cornerRadius: 24)
    }

    private var scanModeSection: some View {
        VStack(spacing: 10) {
            Picker("Scan Mode", selection: $viewModel.scanMode) {
                ForEach(ScanMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            // Fixed-height helper text so the layout doesn't jump when the copy changes with scanMode.
            HStack(spacing: 8) {
                Image(systemName: viewModel.scanMode == .similar ? "sparkles" : "bolt.fill")
                    .foregroundColor(viewModel.scanMode == .similar ? FrostTheme.Colors.brand : FrostTheme.Colors.success)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.scanMode == .similar {
                        Text("Finds visually similar images using AI.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Takes extra time to process.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Finds identical files using fast hashing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("100% accurate and reliable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 32, alignment: .leading)
                .accessibilityElement(children: .combine)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(width: 300)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ThemeToggle()
                    .frame(width: 120)
                    .controlSize(.small)

                Button(action: {
                    viewModel.showUserGuide = true
                }) {
                    Label(AppConstants.Strings.userGuide, systemImage: "book.fill")
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }

            VStack(spacing: 4) {
                Text("© 2026 TwinPixCleaner v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2.0") • Made with ❤️ for macOS")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("Developed by")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button(action: {
                        if let url = URL(string: AppConstants.Strings.linkedinURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text(AppConstants.Strings.developerName)
                            .font(.caption2)
                            .foregroundColor(FrostTheme.Colors.brand)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frostCard(cornerRadius: 20)
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
}

/// A checkmark + text row, used by `aboutSection` to list app capabilities.
private struct FeatureBullet: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(FrostTheme.Colors.success)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
        }
    }
}
