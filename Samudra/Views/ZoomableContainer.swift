import SwiftUI

struct ZoomableContainer<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat
    @Binding var zoomScale: CGFloat
    @Binding var fitScale: CGFloat
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = minScale
        scroll.maximumZoomScale = maxScale
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.delegate = context.coordinator
        scroll.backgroundColor = .systemBackground
        scroll.contentInsetAdjustmentBehavior = .never

        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        host.view.translatesAutoresizingMaskIntoConstraints = true
        scroll.addSubview(host.view)
        scroll.contentSize = contentSize
        context.coordinator.hostingController = host
        context.coordinator.contentView = host.view

        DispatchQueue.main.async {
            fitContent(scroll: scroll)
        }
        context.coordinator.zoomBinding = $zoomScale
        context.coordinator.fitBinding = $fitScale
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content()
    }

    private func fitContent(scroll: UIScrollView) {
        guard scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        let xScale = scroll.bounds.width / contentSize.width
        let yScale = scroll.bounds.height / contentSize.height
        let fit = min(xScale, yScale)
        scroll.minimumZoomScale = fit
        scroll.zoomScale = fit
        DispatchQueue.main.async {
            fitScale = fit
            zoomScale = fit
        }
        centerContent(scroll: scroll)
    }

    fileprivate static func centerContent(scroll: UIScrollView, contentView: UIView) {
        let boundsSize = scroll.bounds.size
        var frame = contentView.frame
        frame.origin.x = frame.size.width < boundsSize.width
            ? (boundsSize.width - frame.size.width) / 2
            : 0
        frame.origin.y = frame.size.height < boundsSize.height
            ? (boundsSize.height - frame.size.height) / 2
            : 0
        contentView.frame = frame
    }

    private func centerContent(scroll: UIScrollView) {
        guard let contentView = scroll.subviews.first else { return }
        Self.centerContent(scroll: scroll, contentView: contentView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        weak var contentView: UIView?
        var zoomBinding: Binding<CGFloat>?
        var fitBinding: Binding<CGFloat>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            contentView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let contentView else { return }
            ZoomableContainer.centerContent(scroll: scrollView, contentView: contentView)
            zoomBinding?.wrappedValue = scrollView.zoomScale
        }
    }
}
