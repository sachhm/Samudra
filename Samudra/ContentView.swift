import SwiftUI
import PencilKit
import UIKit

struct ContentView: View {
    @State private var tool: ToolMode = .route
    @State private var canvasView = PKCanvasView()
    @State private var hazards: [HazardAnnotation] = []
    @State private var notes: [NTMAnnotation] = []
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    @State private var editingNoteID: UUID?
    @State private var pendingNoteText: String = ""
    @State private var showNoteEditor: Bool = false

    @State private var exportImage: UIImage?
    @State private var showShareSheet: Bool = false
    @State private var showClearAlert: Bool = false

    private let chartSize = CGSize(width: 4096, height: 2893)

    var body: some View {
        ZStack {
            ChartPalette.navy.ignoresSafeArea()

            ZoomableContainer(contentSize: chartSize, minScale: 0.2, maxScale: 4.0) {
                ZStack {
                    chartImage
                        .resizable()
                        .frame(width: chartSize.width, height: chartSize.height)

                    ChartCanvasView(
                        canvasView: $canvasView,
                        tool: tool,
                        allowDrawing: tool.usesPencilKit
                    )
                    .frame(width: chartSize.width, height: chartSize.height)

                    AnnotationOverlay(
                        hazards: $hazards,
                        notes: $notes,
                        tool: tool,
                        chartSize: chartSize,
                        canvasView: canvasView,
                        editingNoteID: $editingNoteID,
                        pendingNoteText: $pendingNoteText,
                        showNoteEditor: $showNoteEditor,
                        onEraseInk: eraseInk
                    )
                }
                .frame(width: chartSize.width, height: chartSize.height)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                ToolbarView(
                    tool: $tool,
                    onUndo: { canvasView.undoManager?.undo(); refreshUndo() },
                    onRedo: { canvasView.undoManager?.redo(); refreshUndo() },
                    onClear: { showClearAlert = true },
                    onExport: exportChart,
                    canUndo: canUndo,
                    canRedo: canRedo
                )
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            canvasView.delegate = CanvasDelegateBridge.shared
            CanvasDelegateBridge.shared.onChange = { refreshUndo() }
        }
        .alert("Notice to Mariner", isPresented: $showNoteEditor) {
            TextField("Description", text: $pendingNoteText)
            Button("Cancel", role: .cancel) {
                if let id = editingNoteID, let note = notes.first(where: { $0.id == id }), note.text == "NTM" {
                    notes.removeAll { $0.id == id }
                }
                editingNoteID = nil
            }
            Button("Save") {
                if let id = editingNoteID, let idx = notes.firstIndex(where: { $0.id == id }) {
                    let trimmed = pendingNoteText.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        notes.remove(at: idx)
                    } else {
                        notes[idx] = notes[idx].with(text: trimmed)
                    }
                }
                editingNoteID = nil
            }
        }
        .alert("Clear all annotations?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                canvasView.drawing = PKDrawing()
                hazards.removeAll()
                notes.removeAll()
                refreshUndo()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = exportImage {
                ShareSheet(items: [image])
            }
        }
    }

    private var chartImage: Image {
        let ui = UIImage(named: "sample-chart") ?? PlaceholderChart.render(size: chartSize)
        return Image(uiImage: ui)
    }

    private func eraseInk(at point: CGPoint) {
        let radius: CGFloat = 28
        let eraseRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let remaining = canvasView.drawing.strokes.filter { !$0.renderBounds.intersects(eraseRect) }
        if remaining.count != canvasView.drawing.strokes.count {
            canvasView.drawing = PKDrawing(strokes: remaining)
        }
    }

    private func refreshUndo() {
        canUndo = canvasView.undoManager?.canUndo ?? false
        canRedo = canvasView.undoManager?.canRedo ?? false
    }

    private func exportChart() {
        let baseImage = UIImage(named: "sample-chart") ?? PlaceholderChart.render(size: chartSize)
        if let snap = ChartExporter.snapshot(
            chartImage: baseImage,
            drawing: canvasView.drawing,
            hazards: hazards,
            notes: notes,
            size: chartSize
        ) {
            exportImage = snap
            showShareSheet = true
        }
    }
}

final class CanvasDelegateBridge: NSObject, PKCanvasViewDelegate {
    static let shared = CanvasDelegateBridge()
    var onChange: (() -> Void)?

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onChange?()
    }
}

enum PlaceholderChart {
    static func render(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Water
            cg.setFillColor(UIColor(red: 0.10, green: 0.22, blue: 0.36, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Land mass
            cg.setFillColor(UIColor(red: 0.86, green: 0.80, blue: 0.62, alpha: 1).cgColor)
            let land = UIBezierPath()
            land.move(to: CGPoint(x: 0, y: size.height * 0.62))
            land.addCurve(
                to: CGPoint(x: size.width * 0.55, y: size.height * 0.78),
                controlPoint1: CGPoint(x: size.width * 0.2, y: size.height * 0.55),
                controlPoint2: CGPoint(x: size.width * 0.35, y: size.height * 0.92)
            )
            land.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.55),
                controlPoint1: CGPoint(x: size.width * 0.75, y: size.height * 0.7),
                controlPoint2: CGPoint(x: size.width * 0.9, y: size.height * 0.4)
            )
            land.addLine(to: CGPoint(x: size.width, y: size.height))
            land.addLine(to: CGPoint(x: 0, y: size.height))
            land.close()
            land.fill()

            // Depth contours
            cg.setStrokeColor(UIColor(white: 1, alpha: 0.15).cgColor)
            cg.setLineWidth(1.5)
            for i in stride(from: 0.0, to: 0.55, by: 0.08) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: size.height * (0.55 + i * 0.1)))
                for x in stride(from: 0.0, through: size.width, by: 40) {
                    let y = size.height * (0.5 + i * 0.05) + sin(x * 0.01 + i * 10) * 18
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.stroke()
            }

            // Depth soundings
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor(white: 1, alpha: 0.45)
            ]
            var seed: UInt64 = 7
            for _ in 0..<140 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat(seed % UInt64(size.width))
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let y = CGFloat(seed % UInt64(size.height * 0.55))
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let depth = 5 + Int(seed % 80)
                let s = "\(depth)" as NSString
                s.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
            }

            // Compass rose
            let center = CGPoint(x: size.width * 0.18, y: size.height * 0.22)
            cg.setStrokeColor(UIColor(white: 1, alpha: 0.5).cgColor)
            cg.setLineWidth(2)
            cg.strokeEllipse(in: CGRect(x: center.x - 70, y: center.y - 70, width: 140, height: 140))
            cg.strokeEllipse(in: CGRect(x: center.x - 50, y: center.y - 50, width: 100, height: 100))
            let n = "N" as NSString
            n.draw(at: CGPoint(x: center.x - 6, y: center.y - 90),
                   withAttributes: [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: UIColor.white
                   ])

            // Label
            let label = "DEMO CHART — NOT FOR NAVIGATION" as NSString
            label.draw(at: CGPoint(x: 40, y: size.height - 50),
                       withAttributes: [
                        .font: UIFont.systemFont(ofSize: 18, weight: .heavy),
                        .foregroundColor: UIColor(white: 1, alpha: 0.65)
                       ])
        }
    }
}

#Preview {
    ContentView()
}
