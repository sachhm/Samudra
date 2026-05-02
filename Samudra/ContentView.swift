import SwiftUI
import PencilKit
import UIKit

struct ContentView: View {
    @State private var tool: ToolMode = .draw
    @State private var canvasView = PKCanvasView()
    @State private var hazards: [HazardAnnotation] = []
    @State private var notes: [NTMAnnotation] = []
    @State private var measurements: [Measurement] = []
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
    @State private var pencilLatLong: Coordinate? = nil
    @State private var arcCenter: CGPoint = .zero
    @State private var screenSize: CGSize = .zero
    @State private var currentChart: ChartDocument = ChartCatalog.default
    @State private var chartUIImage: UIImage? = nil
    @State private var chartSize: CGSize = CGSize(width: 4096, height: 2893)

    var body: some View {
        GeometryReader { geo in
            content
                .onAppear { screenSize = geo.size }
                .onChange(of: geo.size) { _, newSize in screenSize = newSize }
                .onChange(of: pencilLocation) { _, _ in
                    pencilLatLong = projectScreenPointToLatLon(pencilLocation)
                }
                .onChange(of: currentChart.id) { _, _ in
                    pencilLatLong = projectScreenPointToLatLon(pencilLocation)
                }
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
                        measurements: $measurements,
                        tool: tool,
                        chartSize: chartSize,
                        canvasView: canvasView,
                        editingNoteID: $editingNoteID,
                        pendingNoteText: $pendingNoteText,
                        showNoteEditor: $showNoteEditor,
                        onEraseInk: eraseInk,
                        projection: currentProjection
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
                    currentChart: currentChart,
                    onSelectChart: switchChart,
                    pencilLatLong: pencilLatLong
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Spacer()
            }

            // Bottom-left scale bar (screen-space, ignores chart rotation)
            VStack {
                Spacer()
                HStack {
                    if let mpp = metersPerScreenPoint {
                        ScaleBarView(metersPerScreenPoint: mpp)
                            .padding(.leading, 18)
                            .padding(.bottom, 18)
                            .transition(.opacity)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            canvasView.delegate = CanvasDelegateBridge.shared
            CanvasDelegateBridge.shared.onChange = { refreshUndo() }
            loadChart(currentChart)
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
                measurements.removeAll()
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
        if let img = chartUIImage {
            return Image(uiImage: img)
        }
        let ui = UIImage(named: "sample-chart") ?? PlaceholderChart.render(size: chartSize)
        return Image(uiImage: ui)
    }

    private func loadChart(_ chart: ChartDocument) {
        currentChart = chart
        if let raster = PDFRasterizer.render(chart, scale: 1.5) {
            chartUIImage = raster.image
            chartSize = raster.size
        } else {
            chartUIImage = nil
            chartSize = CGSize(width: 4096, height: 2893)
        }
    }

    private func switchChart(to chart: ChartDocument) {
        guard chart.id != currentChart.id else { return }
        canvasView.drawing = PKDrawing()
        canvasView.undoManager?.removeAllActions()
        hazards.removeAll()
        notes.removeAll()
        measurements.removeAll()
        refreshUndo()
        loadChart(chart)
    }

    private var currentProjection: UTMProjection? {
        guard let georef = currentChart.georef else { return nil }
        return UTMProjection(georef: georef)
    }

    private var metersPerScreenPoint: Double? {
        guard let georef = currentChart.georef else { return nil }
        let proj = UTMProjection(georef: georef)
        // Distance in meters between (pixel 0,0) and (pixel 100,0), via lat/lon.
        let p0 = proj.pixelToLatLon(CGPoint(x: 0, y: 0))
        let p1 = proj.pixelToLatLon(CGPoint(x: 100, y: 0))
        let metersPer100ChartPixels = Geodesy.distance(p0, p1)
        // chartPixels per screenPoint = 1 / zoomScale
        guard zoomScale > 0 else { return nil }
        return (metersPer100ChartPixels / 100) / zoomScale
    }

    private func projectScreenPointToLatLon(_ screenPoint: CGPoint?) -> Coordinate? {
        guard let screenPoint, let projection = currentProjection else { return nil }
        guard let chartView = chartHostView() else { return nil }
        let chartPixel = chartView.convert(screenPoint, from: nil)
        guard projection.contains(chartPixel) else { return nil }
        return projection.pixelToLatLon(chartPixel)
    }

    private func chartHostView() -> UIView? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else { return nil }
        return Self.findChartHost(window)
    }

    private static func findChartHost(_ view: UIView) -> UIView? {
        if view.accessibilityIdentifier == "samudra.chartHost" { return view }
        for sub in view.subviews {
            if let hit = findChartHost(sub) { return hit }
        }
        return nil
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
