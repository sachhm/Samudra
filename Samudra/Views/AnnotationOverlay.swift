import SwiftUI
import PencilKit

struct AnnotationOverlay: View {
    @Binding var hazards: [HazardAnnotation]
    @Binding var notes: [NTMAnnotation]
    @Binding var measurements: [Measurement]
    let tool: ToolMode
    let chartSize: CGSize
    let canvasView: PKCanvasView
    @Binding var editingNoteID: UUID?
    @Binding var pendingNoteText: String
    @Binding var showNoteEditor: Bool
    let onEraseInk: (CGPoint) -> Void
    let projection: UTMProjection?

    @State private var eraserPoint: CGPoint?
    @State private var draggingID: UUID?
    @State private var pendingMeasureA: CGPoint?
    private let eraserRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            if tool == .hazard || tool == .note || tool == .measure {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location)
                    }
            }

            if tool == .eraser {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(eraserDrag)
            }

            // Measurements — visual layer (lines + labels, no hit-test)
            ForEach(Array(measurements.enumerated()), id: \.element.id) { idx, m in
                MeasurementMark(
                    measurement: m,
                    index: idx + 1,
                    projection: projection,
                    selected: draggingID == m.id
                )
                .allowsHitTesting(false)
            }

            // Measurements — draggable endpoint handles (only hit-tested in measure mode)
            ForEach(Array(measurements.enumerated()), id: \.element.id) { idx, m in
                Group {
                    MeasureEndpointHandle(selected: draggingID == m.id)
                        .position(m.a)
                        .gesture(measureEndpointDrag(id: m.id, endpoint: .a))
                        .accessibilityLabel("Measurement \(idx + 1) point A")
                        .accessibilityHint("Drag to reposition")
                    MeasureEndpointHandle(selected: draggingID == m.id)
                        .position(m.b)
                        .gesture(measureEndpointDrag(id: m.id, endpoint: .b))
                        .accessibilityLabel("Measurement \(idx + 1) point B")
                        .accessibilityHint("Drag to reposition")
                }
                .allowsHitTesting(tool == .measure)
            }

            // Pending measurement first endpoint
            if tool == .measure, let p = pendingMeasureA {
                MeasurePendingMark()
                    .position(p)
                    .allowsHitTesting(false)
            }

            ForEach(Array(hazards.enumerated()), id: \.element.id) { idx, hazard in
                HazardMark(hazard: hazard, index: idx + 1, selected: draggingID == hazard.id, coord: coordFor(hazard.center))
                    .position(hazard.center)
                    .gesture(dragGesture(for: hazard))
                    .allowsHitTesting(tool == .hazard || tool == .note)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        coordFor(hazard.center).map { "Hazard \(idx + 1) at \(CoordinateFormatter.speech($0))" }
                        ?? "Hazard \(idx + 1)"
                    )
                    .accessibilityHint("Drag to reposition")
            }

            ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                NTMMark(note: note, index: idx + 1, selected: draggingID == note.id, coord: coordFor(note.position))
                    .position(note.position)
                    .gesture(dragGesture(for: note))
                    .onTapGesture {
                        editingNoteID = note.id
                        pendingNoteText = note.text
                        showNoteEditor = true
                    }
                    .allowsHitTesting(tool == .hazard || tool == .note)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        coordFor(note.position).map { "Notice to Mariner \(idx + 1): \(note.text) at \(CoordinateFormatter.speech($0))" }
                        ?? "Notice to Mariner \(idx + 1): \(note.text)"
                    )
                    .accessibilityHint("Double tap to edit, drag to reposition")
            }

            if tool == .eraser, let p = eraserPoint {
                EraserCursor(radius: eraserRadius)
                    .position(p)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: chartSize.width, height: chartSize.height)
    }

    private var eraserDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                eraserPoint = value.location
                eraseAt(value.location)
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    eraserPoint = nil
                }
            }
    }

    private func coordFor(_ p: CGPoint) -> Coordinate? {
        guard let projection, projection.contains(p) else { return nil }
        return projection.pixelToLatLon(p)
    }

    private func eraseAt(_ point: CGPoint) {
        hazards.removeAll { hypot($0.center.x - point.x, $0.center.y - point.y) <= $0.radius }
        notes.removeAll { hypot($0.position.x - point.x, $0.position.y - point.y) <= 40 }
        measurements.removeAll { m in
            hypot(m.a.x - point.x, m.a.y - point.y) <= eraserRadius
                || hypot(m.b.x - point.x, m.b.y - point.y) <= eraserRadius
        }
        onEraseInk(point)
    }

    private func handleTap(at location: CGPoint) {
        switch tool {
        case .hazard:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                hazards.append(HazardAnnotation(center: location))
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .note:
            let note = NTMAnnotation(position: location, text: "Note")
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                notes.append(note)
            }
            editingNoteID = note.id
            pendingNoteText = note.text
            showNoteEditor = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .measure:
            // Snap tap to nearest existing endpoint within range — enables chaining.
            let placement = snapToEndpoint(location) ?? location
            if let a = pendingMeasureA {
                let m = Measurement(a: a, b: placement)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    measurements.append(m)
                }
                pendingMeasureA = nil
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                pendingMeasureA = placement
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        default:
            break
        }
    }

    private func dragGesture(for hazard: HazardAnnotation) -> some Gesture {
        DragGesture()
            .onChanged { value in
                draggingID = hazard.id
                guard let idx = hazards.firstIndex(of: hazard) else { return }
                hazards[idx] = hazards[idx].moved(to: value.location)
            }
            .onEnded { _ in draggingID = nil }
    }

    private func dragGesture(for note: NTMAnnotation) -> some Gesture {
        DragGesture()
            .onChanged { value in
                draggingID = note.id
                guard let idx = notes.firstIndex(of: note) else { return }
                notes[idx] = notes[idx].moved(to: value.location)
            }
            .onEnded { _ in draggingID = nil }
    }

    // MARK: - Measurement endpoint manipulation

    private enum MeasurementEndpoint { case a, b }

    private func measureEndpointDrag(id: UUID, endpoint: MeasurementEndpoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let idx = measurements.firstIndex(where: { $0.id == id }) else { return }
                draggingID = id
                let snapped = snapToEndpoint(value.location, excludingMeasurementId: id) ?? value.location
                switch endpoint {
                case .a: measurements[idx] = measurements[idx].movedA(to: snapped)
                case .b: measurements[idx] = measurements[idx].movedB(to: snapped)
                }
            }
            .onEnded { _ in draggingID = nil }
    }

    /// Returns the nearest existing measurement endpoint within snap range, or nil.
    /// Snap range scales with chart resolution — ~40 chart-pixels = ~28pt at 1.5× rasterizer.
    private func snapToEndpoint(_ p: CGPoint, excludingMeasurementId: UUID? = nil) -> CGPoint? {
        let threshold: CGFloat = 40
        var best: (point: CGPoint, dist: CGFloat)? = nil
        for m in measurements {
            if m.id == excludingMeasurementId { continue }
            for candidate in [m.a, m.b] {
                let d = hypot(candidate.x - p.x, candidate.y - p.y)
                if d <= threshold, best == nil || d < best!.dist {
                    best = (candidate, d)
                }
            }
        }
        return best?.point
    }
}

// MARK: - Hazard

private struct HazardMark: View {
    let hazard: HazardAnnotation
    let index: Int
    let selected: Bool
    let coord: Coordinate?

    var body: some View {
        ZStack {
            // Selection ring (subtle, system-tint)
            if selected {
                Circle()
                    .strokeBorder(ChartPalette.routeBlue, lineWidth: 1.5)
                    .frame(width: hazard.radius * 2 + 14, height: hazard.radius * 2 + 14)
            }

            // Hazard dashed circle — maritime convention
            Circle()
                .strokeBorder(
                    ChartPalette.hazardRed,
                    style: StrokeStyle(lineWidth: 2.5, dash: [9, 6])
                )
                .frame(width: hazard.radius * 2, height: hazard.radius * 2)

            // Numeric tag + optional coord subtitle offset above
            VStack(spacing: 2) {
                Text("\(index)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ChartPalette.hazardRed)
                if let coord {
                    Text(CoordinateFormatter.ddm(coord))
                        .font(.system(size: 9, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .glassEffect(.regular, in: Capsule())
            .offset(y: -hazard.radius - 16)
        }
    }
}

// MARK: - NTM (Maps-style pin)

private struct NTMMark: View {
    let note: NTMAnnotation
    let index: Int
    let selected: Bool
    let coord: Coordinate?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if selected {
                    Circle()
                        .strokeBorder(ChartPalette.routeBlue, lineWidth: 1.5)
                        .frame(width: 38, height: 38)
                }
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white, ChartPalette.noteYellow)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }

            VStack(spacing: 0) {
                Text(note.text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let coord {
                    Text(CoordinateFormatter.ddm(coord))
                        .font(.system(size: 9, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: Capsule())
        }
    }
}

// MARK: - Eraser cursor

private struct EraserCursor: View {
    let radius: CGFloat

    var body: some View {
        Circle()
            .strokeBorder(Color.secondary, lineWidth: 1.5)
            .background(
                Circle().fill(Color.secondary.opacity(0.08))
            )
            .frame(width: radius * 2, height: radius * 2)
    }
}

// MARK: - Measurement

private struct MeasurementMark: View {
    let measurement: Measurement
    let index: Int
    let projection: UTMProjection?
    let selected: Bool

    private var midpoint: CGPoint {
        CGPoint(x: (measurement.a.x + measurement.b.x) / 2,
                y: (measurement.a.y + measurement.b.y) / 2)
    }

    private var labelText: String? {
        guard let projection,
              projection.contains(measurement.a),
              projection.contains(measurement.b)
        else { return nil }
        let coordA = projection.pixelToLatLon(measurement.a)
        let coordB = projection.pixelToLatLon(measurement.b)
        let meters = Geodesy.distance(coordA, coordB)
        let nm = meters / 1852
        let bearing = Geodesy.bearing(coordA, coordB)
        let nmStr: String
        if nm >= 1 {
            nmStr = String(format: "%.2f nm", nm)
        } else {
            nmStr = String(format: "%d m", Int(meters.rounded()))
        }
        return String(format: "%@ · %03d°T", nmStr, Int(bearing.rounded()))
    }

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: measurement.a)
                path.addLine(to: measurement.b)
            }
            .stroke(
                ChartPalette.routeBlue,
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )

            if let labelText {
                Text(labelText)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
                    .position(midpoint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            labelText.map { "Measurement \(index): \($0)" } ?? "Measurement \(index)"
        )
    }
}

private struct MeasurePendingMark: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(ChartPalette.routeBlue, lineWidth: 2)
                .frame(width: 16, height: 16)
            Circle()
                .fill(ChartPalette.routeBlue.opacity(0.3))
                .frame(width: 16, height: 16)
            Text("A")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ChartPalette.routeBlue)
                .offset(y: -14)
        }
    }
}

/// Draggable endpoint handle for a committed measurement.
/// Visible filled dot at endpoint with an enlarged transparent hit area
/// so finger/pencil can grab + drag the handle without pixel-perfect aim.
private struct MeasureEndpointHandle: View {
    let selected: Bool
    private let visibleSize: CGFloat = 14
    private let hitSize: CGFloat = 36

    var body: some View {
        ZStack {
            // Hit target (transparent, enlarged)
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: hitSize, height: hitSize)
                .contentShape(Circle())

            // Selection ring
            if selected {
                Circle()
                    .strokeBorder(ChartPalette.routeBlue.opacity(0.5), lineWidth: 1.5)
                    .frame(width: visibleSize + 10, height: visibleSize + 10)
            }

            // Visible dot
            Circle()
                .fill(ChartPalette.routeBlue)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                .frame(width: visibleSize, height: visibleSize)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
    }
}
