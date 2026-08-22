import SwiftUI
import AppKit

struct SkippedFilesSheetView: View {
    let summary: SkippedSummary
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedReason: SkipReason? = nil
    @State private var searchText = ""
    @State private var copiedToClipboard = false
    
    private var filteredItems: [SkippedItem] {
        var items = summary.sampleItems
        if let selectedReason {
            items = items.filter { $0.reason == selectedReason }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.detail?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    categoryCards
                    
                    if summary.reasonCounts[.inCloudOnly, default: 0] > 0 {
                        infoNoticeCallout
                    }
                    
                    categoryFilterTabs
                    
                    sampleListSection
                }
                .padding(20)
            }
            
            Divider()
            footerBar
        }
        .frame(width: 620, height: 520)
        .frostBackground()
    }
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(FrostTheme.Colors.brand)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Skipped Items")
                    .font(.headline)
                Text("\(summary.totalCount) item\(summary.totalCount == 1 ? "" : "s") skipped during scan")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
    
    private var categoryCards: some View {
        HStack(spacing: 12) {
            if let cloudCount = summary.reasonCounts[.inCloudOnly], cloudCount > 0 {
                ReasonStatCard(
                    icon: "icloud.slash.fill",
                    tint: .blue,
                    count: cloudCount,
                    title: "In iCloud",
                    subtitle: "Not on this Mac"
                )
            }
            
            if let mediaCount = summary.reasonCounts[.unsupportedFormat], mediaCount > 0 {
                ReasonStatCard(
                    icon: "video.slash.fill",
                    tint: .purple,
                    count: mediaCount,
                    title: "Videos & GIFs",
                    subtitle: "Non-still media"
                )
            }
            
            if let errorCount = summary.reasonCounts[.unreadableFile], errorCount > 0 {
                ReasonStatCard(
                    icon: "exclamationmark.triangle.fill",
                    tint: FrostTheme.Colors.warning,
                    count: errorCount,
                    title: "Unreadable",
                    subtitle: "Corrupt or locked"
                )
            }
        }
    }
    
    private var infoNoticeCallout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Why are iCloud photos skipped?")
                    .font(.system(size: 12, weight: .semibold))
                Text("TwinPixCleaner skips photos that exist only in iCloud to avoid downloading gigabytes over your network and filling your Mac's storage. To include them, download them in Apple Photos first.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var categoryFilterTabs: some View {
        HStack {
            Picker("Filter", selection: $selectedReason) {
                Text("All (\(summary.totalCount))").tag(nil as SkipReason?)
                
                ForEach(SkipReason.allCases) { reason in
                    if let count = summary.reasonCounts[reason], count > 0 {
                        Text("\(reason.rawValue) (\(count))").tag(reason as SkipReason?)
                    }
                }
            }
            .pickerStyle(.segmented)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Search names…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 140)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
        }
    }
    
    private var sampleListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sample Skipped Files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if summary.totalCount > summary.sampleItems.count {
                    Text("Showing \(filteredItems.count) of \(summary.sampleItems.count) samples")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            if filteredItems.isEmpty {
                HStack {
                    Spacer()
                    Text("No skipped items match your filter")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(filteredItems) { item in
                        SkippedItemRow(item: item)
                    }
                }
            }
        }
    }
    
    private var footerBar: some View {
        HStack {
            Button(action: copySampleNames) {
                Label(copiedToClipboard ? "Copied!" : "Copy Sample Names", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundColor(copiedToClipboard ? .green : .accentColor)
            
            Spacer()
            
            Text("Press Esc to close")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    private func copySampleNames() {
        let names = filteredItems.map { $0.name }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(names, forType: .string)
        withAnimation {
            copiedToClipboard = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
}

private struct ReasonStatCard: View {
    let icon: String
    let tint: Color
    let count: Int
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(tint)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

private struct SkippedItemRow: View {
    let item: SkippedItem
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.reason.icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            Text(item.reason.rawValue)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(iconColor.opacity(0.12))
                .foregroundColor(iconColor)
                .cornerRadius(6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private var iconColor: Color {
        switch item.reason {
        case .inCloudOnly:
            return .blue
        case .unsupportedFormat:
            return .purple
        case .unreadableFile:
            return .orange
        }
    }
}
