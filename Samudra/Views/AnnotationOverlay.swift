import SwiftUI

struct AnnotationOverlay: View {
    @Binding var hazards: [HazardAnnotation]
    @Binding var notes: [NoteAnnotation]
    let tool: ToolMode
    let chartSize: CGSize
    @Binding var editingNoteID: UUID?
    @Binding var pendingNoteText: String
    @Binding var showNoteEditor: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hit layer — only active when placing hazard/note
            if tool == .hazard || tool == .note {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location)
                    }
            }

            ForEach(hazards) { hazard in
                HazardCircle(hazard: hazard)
                    .position(hazard.center)
                    .gesture(dragGesture(for: hazard))
            }

            ForEach(notes) { note in
                NotePin(note: note)
                    .position(note.position)
                    .gesture(dragGesture(for: note))
                    .onTapGesture {
                        editingNoteID = note.id
                        pendingNoteText = note.text
                        showNoteEditor = true
                    }
            }
        }
        .frame(width: chartSize.width, height: chartSize.height)
        .allowsHitTesting(tool != .route && tool != .eraser)
    }

    private func handleTap(at location: CGPoint) {
        switch tool {
        case .hazard:
            hazards.append(HazardAnnotation(center: location))
        case .note:
            let note = NoteAnnotation(position: location, text: "Note")
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

    private func dragGesture(for note: NoteAnnotation) -> some Gesture {
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

private struct NotePin: View {
    let note: NoteAnnotation

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
