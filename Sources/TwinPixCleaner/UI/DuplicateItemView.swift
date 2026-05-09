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
            // Image
            ZStack(alignment: .topTrailing) {
                UniversalImageView(url: url)
                    .frame(width: 200, height: 200)
                    .clipped()
                
                // Selection Checkbox
                Button(action: onToggleSelection) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
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
                
                // Quick Look button (bottom-left on hover)
                if isHovering {
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: onPreview) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: AppConstants.Icons.eyePreview)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    .padding(8)
                    .transition(.opacity)
                    .allowsHitTesting(true)
                }
                
                // Hover Overlay (metadata)
                if isHovering {
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
            
            // Info Section with Better Contrast
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
                
                // Action Buttons
                HStack(spacing: 0) {
                    // Keep This Button
                    Button(action: onKeep) {
                        HStack(spacing: 4) {
                            Image(systemName: AppConstants.Icons.keepShield)
                                .font(.system(size: 11, weight: .medium))
                            Text(AppConstants.Strings.keepThis)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Delete Button
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: AppConstants.Icons.trash)
                                .font(.system(size: 11, weight: .medium))
                            Text(AppConstants.Strings.trash)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .frame(width: 200)
            .background(.ultraThinMaterial)
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
}
