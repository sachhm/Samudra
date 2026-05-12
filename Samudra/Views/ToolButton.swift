import SwiftUI

/// Tool button used inside a glass capsule menu. No own glass body —
/// the parent capsule provides the surface.
struct ToolOrb: View {
    let mode: ToolMode
    let active: Bool
    var diameter: CGFloat = 46
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: active ? mode.symbolFilled : mode.symbol)
                .font(.system(size: diameter * 0.42, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(active ? mode.tint : Color.primary.opacity(0.85))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .background(
                    Circle()
                        .fill(active ? mode.tint.opacity(0.18) : Color.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
    }
}

/// Secondary action button inside same capsule menu.
struct GlassDisc: View {
    let symbol: String
    var role: ButtonRole? = nil
    var enabled: Bool = true
    var diameter: CGFloat = 42
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(role: role) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.40, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    enabled
                    ? (role == .destructive ? Color.red : Color.primary.opacity(0.8))
                    : Color.primary.opacity(0.3)
                )
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? symbol : label)
    }
}

/// Subtle divider between sections inside a glass capsule.
struct MenuDivider: View {
    enum Orientation { case horizontal, vertical }
    let orientation: Orientation

    var body: some View {
        Group {
            switch orientation {
            case .horizontal:
                Capsule().fill(.quaternary).frame(width: 26, height: 1)
            case .vertical:
                Capsule().fill(.quaternary).frame(width: 1, height: 26)
            }
        }
    }
}
