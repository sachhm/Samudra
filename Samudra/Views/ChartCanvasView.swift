import SwiftUI
import PencilKit

struct ChartCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let tool: ToolMode
    let allowDrawing: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = pkTool(for: tool)
        canvasView.isUserInteractionEnabled = allowDrawing
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = pkTool(for: tool)
        uiView.isUserInteractionEnabled = allowDrawing
    }

    private func pkTool(for mode: ToolMode) -> PKTool {
        switch mode {
        case .route:
            return PKInkingTool(.pen, color: UIColor(ChartPalette.routeBlue), width: 3)
        case .eraser:
            return PKEraserTool(.bitmap)
        case .hazard, .note:
            return PKInkingTool(.pen, color: .clear, width: 0)
        }
    }
}
