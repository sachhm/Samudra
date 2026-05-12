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

    private let eraserRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placement layer for hazard/note tools
            if tool == .hazard || tool == .note {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location)
                    }
            }

            // Eraser drag layer — eats touches, drags erase annotations + ink
            if tool == .eraser {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(eraserDrag)
            }

            ForEach(hazards) { hazard in
                HazardCircle(hazard: hazard)
                    .position(hazard.center)
                    .gesture(dragGesture(for: hazard))
                    .allowsHitTesting(tool == .hazard || tool == .note)
            }

            ForEach(notes) { note in
                NTMPin(note: note)
                    .position(note.position)
                    .gesture(dragGesture(for: note))
                    .onTapGesture {
                        editingNoteID = note.id
                        pendingNoteText = note.text
                        showNoteEditor = true
                    }
                    .allowsHitTesting(tool == .hazard || tool == .note)
            }
        }
        .frame(width: chartSize.width, height: chartSize.height)
    }

    private var eraserDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                eraseAt(value.location)
            }
    }

    private func eraseAt(_ point: CGPoint) {
        // Hazards: remove if point within radius
        hazards.removeAll { hypot($0.center.x - point.x, $0.center.y - point.y) <= $0.radius }
        // Notes: remove if point within ~40pt of pin position
        notes.removeAll { hypot($0.position.x - point.x, $0.position.y - point.y) <= 40 }
        // Ink: erase strokes within eraserRadius
        onEraseInk(point)
    }

    private func handleTap(at location: CGPoint) {
        switch tool {
        case .hazard:
            hazards.append(HazardAnnotation(center: location))
        case .note:
            let note = NTMAnnotation(position: location, text: "NTM")
            notes.append(note)
            editingNoteID = note.id
            pendingNoteText = note.text
            showNoteEditor = true
        default:
            break
        }
    }

    private func dragGesture(for hazard: HazardAnnotation) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let idx = hazards.firstIndex(of: hazard) else { return }
                hazards[idx] = hazards[idx].moved(to: value.location)
            }
    }

    private func dragGesture(for note: NTMAnnotation) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let idx = notes.firstIndex(of: note) else { return }
                notes[idx] = notes[idx].moved(to: value.location)
            }
    }
}

private struct HazardCircle: View {
    let hazard: HazardAnnotation

    var body: some View {
        ZStack {
            Circle()
                .stroke(ChartPalette.hazardRed, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .frame(width: hazard.radius * 2, height: hazard.radius * 2)
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ChartPalette.hazardRed)
                .font(.system(size: 18, weight: .bold))
        }
    }
}

private struct NTMPin: View {
    let note: NTMAnnotation

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(ChartPalette.noteYellow)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            Text(note.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ChartPalette.navy)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ChartPalette.noteYellow)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ChartPalette.navy.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
