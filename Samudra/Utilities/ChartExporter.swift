import SwiftUI
import PencilKit
import UIKit

enum ChartExporter {
    @MainActor
    static func snapshot(
        chartImage: UIImage,
        drawing: PKDrawing,
        hazards: [HazardAnnotation],
        notes: [NTMAnnotation],
        size: CGSize
    ) -> UIImage? {
        let renderer = ImageRenderer(content:
            ZStack {
                Image(uiImage: chartImage)
                    .resizable()
                    .frame(width: size.width, height: size.height)

                Image(uiImage: drawing.image(from: CGRect(origin: .zero, size: size), scale: 2))
                    .resizable()
                    .frame(width: size.width, height: size.height)

                ForEach(hazards) { hazard in
                    Circle()
                        .stroke(ChartPalette.hazardRed, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        .frame(width: hazard.radius * 2, height: hazard.radius * 2)
                        .position(hazard.center)
                }

                ForEach(notes) { note in
                    Text(note.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ChartPalette.navy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6).fill(ChartPalette.noteYellow)
                        )
                        .position(note.position)
                }
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
