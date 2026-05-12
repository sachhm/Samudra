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
        VStack(spacing: 6) {
            ForEach(ToolMode.allCases) { mode in
                ToolOrb(mode: mode, active: tool == mode, diameter: 46) {
                    withAnimation(.snappy) {
                        tool = mode
                    }
                }
            }

            MenuDivider(orientation: .horizontal)
                .padding(.vertical, 2)

            GlassDisc(symbol: "arrow.uturn.backward", enabled: canUndo, label: "Undo", action: onUndo)
            GlassDisc(symbol: "arrow.uturn.forward", enabled: canRedo, label: "Redo", action: onRedo)
            GlassDisc(symbol: "trash", role: .destructive, label: "Clear", action: onClear)

            MenuDivider(orientation: .horizontal)
                .padding(.vertical, 2)

            GlassDisc(symbol: "square.and.arrow.up", label: "Export", action: onExport)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .glassEffect(.regular, in: Capsule())
    }
}
