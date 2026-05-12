import SwiftUI
import PencilKit
import UIKit

struct ContentView: View {
    @State private var tool: ToolMode = .draw
    @State private var canvasView = PKCanvasView()
    @State private var hazards: [HazardAnnotation] = []
    @State private var notes: [NTMAnnotation] = []
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    @State private var editingNoteID: UUID?
    @State private var pendingNoteText: String = ""
    @State private var showNoteEditor: Bool = false

    @State private var exportItems: [Any] = []
    @State private var showShareSheet: Bool = false
    @State private var showClearAlert: Bool = false

    @State private var showExportSheet: Bool = false
    @State private var voyageMetadata: VoyageMetadata = .empty
    @State private var exportErrorMessage: String?

    @State private var zoomScale: CGFloat = 1
    @State private var fitScale: CGFloat = 1

    @State private var showArc: Bool = false
    @State private var pencilLocation: CGPoint?
    @State private var arcCenter: CGPoint = .zero
    @State private var screenSize: CGSize = .zero

    private let chartSize = CGSize(width: 4096, height: 2893)
    private let chartName = "WA412 ROTTNEST IS."

    var body: some View {
        GeometryReader { geo in
            content
                .onAppear { screenSize = geo.size }
                .onChange(of: geo.size) { _, newSize in screenSize = newSize }
        }
    }

    private var content: some View {
        ZStack {
            ChartPalette.navy.ignoresSafeArea()

            ZoomableContainer(
                contentSize: chartSize,
                minScale: 0.2,
                maxScale: 4.0,
                zoomScale: $zoomScale,
                fitScale: $fitScale
            ) {
                ZStack {
                    chartImage
                        .resizable()
                        .frame(width: chartSize.width, height: chartSize.height)

                    ChartCanvasView(
                        canvasView: $canvasView,
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

            // Pencil hover tracker (receives hover events only; touches pass through)
            PencilHoverTracker(location: $pencilLocation)
                .ignoresSafeArea()

            // Pencil squeeze listener (transparent UIPencilInteraction host)
            PencilSqueezeListener(onSqueeze: openOrMoveArc)
                .allowsHitTesting(false)

            // Rail — always visible
            HStack {
                ToolbarView(
                    tool: $tool,
                    onUndo: { canvasView.undoManager?.undo(); refreshUndo() },
                    onRedo: { canvasView.undoManager?.redo(); refreshUndo() },
                    onClear: { showClearAlert = true },
                    onExport: exportChart,
                    canUndo: canUndo,
                    canRedo: canRedo
                )
                .padding(.leading, 18)
                Spacer()
            }

            // Arc — pops at pencil location on squeeze; rail unaffected
            if showArc {
                Color.black.opacity(0.0001)
                    .ignoresSafeArea()
                    .onTapGesture { dismissArc() }
                    .transition(.opacity)

                ArcToolMenu(
                    center: arcCenter,
                    screenSize: screenSize,
                    tool: $tool,
                    onSelect: dismissArc
                )
                .ignoresSafeArea()
            }

            // Top HUD bar
            VStack {
                HUDView(
                    tool: tool,
                    hazardCount: hazards.count,
                    ntmCount: notes.count,
                    zoomPercent: zoomPercent,
                    chartName: chartName
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Spacer()
            }
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
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(
                metadata: $voyageMetadata,
                hazardCount: hazards.count,
                ntmCount: notes.count,
                onExport: handleExport(format:),
                onCancel: { showExportSheet = false }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if !exportItems.isEmpty {
                ShareSheet(items: exportItems)
            }
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    /// Squeeze handler — always opens arc at current pencil location.
    /// If already open, relocates to new pencil position.
    private func openOrMoveArc() {
        let newCenter = pencilLocation ?? CGPoint(
            x: screenSize.width * 0.30,
            y: screenSize.height * 0.55
        )
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        if showArc {
            withAnimation(.snappy) {
                arcCenter = newCenter
            }
        } else {
            arcCenter = newCenter
            withAnimation(.snappy) {
                showArc = true
            }
        }
    }

    private func dismissArc() {
        withAnimation(.snappy) {
            showArc = false
        }
    }

    private var zoomPercent: Int {
        guard fitScale > 0 else { return 100 }
        return Int((zoomScale / fitScale) * 100)
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
        showExportSheet = true
    }

    private func handleExport(format: ExportFormat) {
        let baseImage = UIImage(named: "sample-chart") ?? PlaceholderChart.render(size: chartSize)
        let drawingPNG = canvasView.drawing.image(
            from: CGRect(origin: .zero, size: chartSize),
            scale: 1
        )
        let payload = ExportPayload(
            metadata: voyageMetadata,
            format: format,
            chartImage: baseImage,
            chartSize: chartSize,
            drawingPNG: drawingPNG,
            hazards: hazards,
            ntms: notes,
            generatedAt: .now
        )

        do {
            let result = try ExportService.export(payload)
            exportItems = [result.fileURL]
            showExportSheet = false
            showShareSheet = true
        } catch {
            exportErrorMessage = "Export skeleton — \(format.label) handler not wired yet."
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
