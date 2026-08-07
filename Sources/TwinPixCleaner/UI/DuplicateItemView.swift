import SwiftUI

struct DuplicateItemView: View {
    let url: URL
    let isSelected: Bool
    let metadata: String
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    let onKeep: () -> Void
    let onPreview: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            thumbnail
            infoSection
        }
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .background(.ultraThinMaterial)
        .cornerRadius(AppConstants.UI.defaultCornerRadius)
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius)
                        .strokeBorder(FrostTheme.accentGradient, lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
            }
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.08),
            radius: isSelected ? 8 : 3,
            y: isSelected ? 4 : 1
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            UniversalImageView(url: url)
                .frame(width: 200, height: 200)
                .clipped()

            selectionCheckbox

            if isHovering {
                quickLookHint
                metadataOverlay
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityValue(metadata)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default) { onToggleSelection() }
        .accessibilityAction(named: Text("Preview")) { onPreview() }
    }

    private var selectionCheckbox: some View {
        Button(action: onToggleSelection) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 28, height: 28)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(FrostTheme.accentGradient)
                        .symbolRenderingMode(.hierarchical)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .focusable() // Enable keyboard focus
        .padding(8)
        .accessibilityHidden(true) // toggle is exposed via the thumbnail's own accessibility action
    }

    private var quickLookHint: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: onPreview) {
                    HStack(spacing: 6) {
                        Image(systemName: AppConstants.Icons.eyePreview)
                            .font(.system(size: 12, weight: .medium))
                        Text("Space to Preview")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(8)
        .transition(.opacity)
        .allowsHitTesting(true)
        .accessibilityHidden(true) // preview is exposed via the thumbnail's own accessibility action
    }

    private var metadataOverlay: some View {
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
        .accessibilityHidden(true) // metadata is exposed via the thumbnail's accessibilityValue, not just on hover
    }

    private var infoSection: some View {
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

            HStack(spacing: 0) {
                ActionBarButton(icon: AppConstants.Icons.keepShield, title: AppConstants.Strings.keepThis, tint: FrostTheme.Colors.brand, action: onKeep)
                Divider().frame(height: 20)
                ActionBarButton(icon: AppConstants.Icons.trash, title: AppConstants.Strings.trash, tint: FrostTheme.Colors.destructive, action: onDelete)
            }
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
    }
}

/// A pill-less inline action button used in the item's bottom action bar (Keep This / Delete).
private struct ActionBarButton: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
