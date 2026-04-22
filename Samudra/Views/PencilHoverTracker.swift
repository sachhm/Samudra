import SwiftUI
import UIKit

struct PencilHoverTracker: UIViewRepresentable {
    @Binding var location: CGPoint?

    func makeUIView(context: Context) -> UIView {
        let view = HoverOnlyView()
        let hover = UIHoverGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        view.addGestureRecognizer(hover)
        context.coordinator.binding = $location
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.binding = $location
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var binding: Binding<CGPoint?>?

        @objc func handle(_ g: UIHoverGestureRecognizer) {
            switch g.state {
            case .began, .changed:
                // Emit in window coordinates so downstream UIView.convert(_, from: nil) works.
                binding?.wrappedValue = g.location(in: nil)
            case .ended, .cancelled, .failed:
                // Retain last known location for squeeze fallback
                break
            default:
                break
            }
        }
    }

    // Receives hover events but passes touches through.
    private final class HoverOnlyView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if event?.type == .hover {
                return self
            }
            return nil
        }
    }
}
