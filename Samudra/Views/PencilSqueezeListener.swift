import SwiftUI
import UIKit

struct PencilSqueezeListener: UIViewRepresentable {
    let onSqueeze: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughView()
        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        context.coordinator.onSqueeze = onSqueeze
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSqueeze = onSqueeze
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIPencilInteractionDelegate {
        var onSqueeze: () -> Void = {}

        @available(iOS 17.5, *)
        func pencilInteraction(
            _ interaction: UIPencilInteraction,
            didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
        ) {
            if squeeze.phase == .ended {
                DispatchQueue.main.async { [weak self] in
                    self?.onSqueeze()
                }
            }
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [weak self] in
                self?.onSqueeze()
            }
        }
    }

    private final class PassthroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
    }
}
