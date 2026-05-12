import SwiftUI
import PencilKit

struct ChartCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let allowDrawing: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = PKInkingTool(.pen, color: UIColor(ChartPalette.routeBlue), width: 5)
        canvasView.isUserInteractionEnabled = allowDrawing
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = allowDrawing
    }
}
