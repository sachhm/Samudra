import UIKit
import CoreGraphics

struct RasterizedChart {
    let image: UIImage
    let size: CGSize
}

enum PDFRasterizer {
    /// Render first page of a bundled PDF to a UIImage at the requested upscale.
    /// Returns nil if PDF missing or unrenderable.
    static func render(_ chart: ChartDocument, scale: CGFloat = 1.5) -> RasterizedChart? {
        guard
            let url = chart.bundleURL,
            let doc = CGPDFDocument(url as CFURL),
            let page = doc.page(at: 1)
        else { return nil }

        let cropBox = page.getBoxRect(.cropBox)
        let rotation = page.rotationAngle
        let pageSize: CGSize
        switch rotation {
        case 90, 270:
            pageSize = CGSize(width: cropBox.height, height: cropBox.width)
        default:
            pageSize = cropBox.size
        }

        let pixelSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)

        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: pixelSize))

            cg.saveGState()
            cg.translateBy(x: 0, y: pixelSize.height)
            cg.scaleBy(x: 1, y: -1)
            cg.scaleBy(x: scale, y: scale)

            let transform = page.getDrawingTransform(
                .cropBox,
                rect: CGRect(origin: .zero, size: pageSize),
                rotate: 0,
                preserveAspectRatio: true
            )
            cg.concatenate(transform)
            cg.drawPDFPage(page)
            cg.restoreGState()
        }

        return RasterizedChart(image: image, size: pixelSize)
    }
}
