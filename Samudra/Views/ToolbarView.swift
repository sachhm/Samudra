import SwiftUI

struct ToolbarView: View {
    @Binding var tool: ToolMode
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClear: () -> Void
    let onExport: () -> Void
    let canUndo: Bool
    let canRedo: Bool

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ToolMode.allCases) { mode in
                toolButton(mode)
            }

            Divider()
                .frame(height: 32)
                .overlay(ChartPalette.border)

            iconButton(symbol: "arrow.uturn.backward", enabled: canUndo, action: onUndo)
            iconButton(symbol: "arrow.uturn.forward", enabled: canRedo, action: onRedo)
            iconButton(symbol: "trash", enabled: true, action: onClear)

            Divider()
                .frame(height: 32)
                .overlay(ChartPalette.border)

            iconButton(symbol: "square.and.arrow.up", enabled: true, action: onExport)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ChartPalette.surface)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ChartPalette.border, lineWidth: 1)
        )
    }

    private func toolButton(_ mode: ToolMode) -> some View {
        let active = mode == tool
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            tool = mode
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(mode.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(active ? ChartPalette.navy : ChartPalette.textPrimary)
            .frame(width: 72, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(active ? mode.tint : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .foregroundStyle(enabled ? ChartPalette.textPrimary : ChartPalette.textSecondary.opacity(0.5))
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}
