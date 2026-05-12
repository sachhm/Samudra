import SwiftUI
import PencilKit

struct AnnotationOverlay: View {
    @Binding var hazards: [HazardAnnotation]
    @Binding var notes: [NTMAnnotation]
    let tool: ToolMode
    let chartSize: CGSize
    let canvasView: PKCanvasView
    @Binding var editingNoteID: UUID?
    @Binding var pendingNoteText: String
    @Binding var showNoteEditor: Bool
    let onEraseInk: (CGPoint) -> Void

    @State private var eraserPoint: CGPoint?
    @State private var draggingID: UUID?
    private let eraserRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            if tool == .hazard || tool == .note {
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

            ForEach(Array(hazards.enumerated()), id: \.element.id) { idx, hazard in
                HazardMark(hazard: hazard, index: idx + 1, selected: draggingID == hazard.id)
                    .position(hazard.center)
                    .gesture(dragGesture(for: hazard))
                    .allowsHitTesting(tool == .hazard || tool == .note)
            }

            ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                NTMMark(note: note, index: idx + 1, selected: draggingID == note.id)
                    .position(note.position)
                    .gesture(dragGesture(for: note))
                    .onTapGesture {
                        editingNoteID = note.id
                        pendingNoteText = note.text
                        showNoteEditor = true
                    }
                    .allowsHitTesting(tool == .hazard || tool == .note)
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

    private func eraseAt(_ point: CGPoint) {
        hazards.removeAll { hypot($0.center.x - point.x, $0.center.y - point.y) <= $0.radius }
        notes.removeAll { hypot($0.position.x - point.x, $0.position.y - point.y) <= 40 }
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
}

// MARK: - Hazard

private struct HazardMark: View {
    let hazard: HazardAnnotation
    let index: Int
    let selected: Bool

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

            // Small numeric tag offset above
            Text("\(index)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ChartPalette.hazardRed)
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

            Text(note.text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
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
