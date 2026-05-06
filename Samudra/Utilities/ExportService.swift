import SwiftUI
import PencilKit
import UIKit

enum ExportError: LocalizedError {
    case renderFailed
    case writeFailed
    case encodingFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .renderFailed: "Failed to render chart"
        case .writeFailed: "Failed to write export file"
        case .encodingFailed: "Failed to encode export payload"
        case .unsupportedFormat: "Unsupported export format"
        }
    }
}

@MainActor
enum ExportService {

    // MARK: - Public entry point

    static func export(_ payload: ExportPayload) throws -> ExportResult {
        switch payload.format {
        case .png:
            return try exportPNG(payload)
        case .pdf:
            return try exportPDF(payload)
        case .json:
            return try exportJSON(payload)
        }
    }

    // MARK: - PNG

    private static func exportPNG(_ payload: ExportPayload) throws -> ExportResult {
        guard let flat = renderFlattenedChart(payload) else {
            throw ExportError.renderFailed
        }
        guard let data = flat.pngData() else {
            throw ExportError.encodingFailed
        }
        let filename = suggestedFilename(payload)
        let url = tempURL(filename: filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed
        }
        return ExportResult(fileURL: url, preview: flat, suggestedFilename: filename)
    }

    // MARK: - PDF

    private static func exportPDF(_ payload: ExportPayload) throws -> ExportResult {
        let pageSize = CGSize(width: 842, height: 595) // A4 landscape @ 72dpi
        let bounds = CGRect(origin: .zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Samudra Passage Plan",
            kCGPDFContextAuthor as String: payload.metadata.pilotName.isEmpty
                ? "Samudra" : payload.metadata.pilotName,
            kCGPDFContextCreator as String: "Samudra — Wärtsilä Pilot PRO concept"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        let filename = suggestedFilename(payload)
        let url = tempURL(filename: filename)

        let flattened = renderFlattenedChart(payload)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                drawCoverPage(in: bounds, payload: payload)

                ctx.beginPage()
                drawChartPage(in: bounds, chart: flattened, payload: payload)

                ctx.beginPage()
                drawManifestPage(in: bounds, payload: payload)
            }
        } catch {
            throw ExportError.writeFailed
        }

        return ExportResult(fileURL: url, preview: flattened, suggestedFilename: filename)
    }

    // MARK: - JSON

    private static func exportJSON(_ payload: ExportPayload) throws -> ExportResult {
        struct AnnotationCoord: Codable {
            let lat: Double
            let lon: Double
        }
        struct HazardEntry: Codable {
            let id: String
            let center_px: [CGFloat]
            let radius_px: CGFloat
            let wgs84: AnnotationCoord?
        }
        struct NTMEntry: Codable {
            let id: String
            let position_px: [CGFloat]
            let text: String
            let wgs84: AnnotationCoord?
        }
        struct MeasurementEntry: Codable {
            let id: String
            let a_px: [CGFloat]
            let b_px: [CGFloat]
            let a_wgs84: AnnotationCoord?
            let b_wgs84: AnnotationCoord?
            let meters: Double?
            let nautical_miles: Double?
            let bearing_true_degrees: Double?
        }
        struct JSONEnvelope: Codable {
            let schemaVersion: Int
            let generatedAt: Date
            let chartId: String
            let chartSize: CGSizeCodable
            let metadata: VoyageMetadata
            let hazards: [HazardEntry]
            let ntms: [NTMEntry]
            let measurements: [MeasurementEntry]
        }

        func coordFor(_ p: CGPoint) -> AnnotationCoord? {
            guard let proj = payload.projection, proj.contains(p) else { return nil }
            let c = proj.pixelToLatLon(p)
            return AnnotationCoord(lat: c.lat, lon: c.lon)
        }

        let hazards = payload.hazards.map {
            HazardEntry(
                id: $0.id.uuidString,
                center_px: [$0.center.x, $0.center.y],
                radius_px: $0.radius,
                wgs84: coordFor($0.center)
            )
        }
        let ntms = payload.ntms.map {
            NTMEntry(
                id: $0.id.uuidString,
                position_px: [$0.position.x, $0.position.y],
                text: $0.text,
                wgs84: coordFor($0.position)
            )
        }
        let measurements = payload.measurements.map { m -> MeasurementEntry in
            let aCoord = coordFor(m.a)
            let bCoord = coordFor(m.b)
            let meters: Double?
            let bearing: Double?
            if let proj = payload.projection,
               proj.contains(m.a), proj.contains(m.b) {
                let cA = proj.pixelToLatLon(m.a)
                let cB = proj.pixelToLatLon(m.b)
                meters = Geodesy.distance(cA, cB)
                bearing = Geodesy.bearing(cA, cB)
            } else {
                meters = nil
                bearing = nil
            }
            return MeasurementEntry(
                id: m.id.uuidString,
                a_px: [m.a.x, m.a.y],
                b_px: [m.b.x, m.b.y],
                a_wgs84: aCoord,
                b_wgs84: bCoord,
                meters: meters,
                nautical_miles: meters.map { $0 / 1852 },
                bearing_true_degrees: bearing
            )
        }

        let envelope = JSONEnvelope(
            schemaVersion: 2,
            generatedAt: payload.generatedAt,
            chartId: payload.chartId,
            chartSize: CGSizeCodable(width: payload.chartSize.width, height: payload.chartSize.height),
            metadata: payload.metadata,
            hazards: hazards,
            ntms: ntms,
            measurements: measurements
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            throw ExportError.encodingFailed
        }

        let filename = suggestedFilename(payload)
        let url = tempURL(filename: filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed
        }
        return ExportResult(fileURL: url, preview: nil, suggestedFilename: filename)
    }

    // MARK: - Flattened chart raster

    private static func renderFlattenedChart(_ payload: ExportPayload) -> UIImage? {
        let size = payload.chartSize
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            payload.chartImage.draw(in: CGRect(origin: .zero, size: size))

            if let drawing = payload.drawingPNG {
                drawing.draw(in: CGRect(origin: .zero, size: size))
            }

            let ctx = UIGraphicsGetCurrentContext()!

            // Hazards
            ctx.setStrokeColor(UIColor(red: 0.90, green: 0.36, blue: 0.36, alpha: 1).cgColor)
            ctx.setLineWidth(4)
            ctx.setLineDash(phase: 0, lengths: [12, 8])
            for h in payload.hazards {
                let rect = CGRect(
                    x: h.center.x - h.radius,
                    y: h.center.y - h.radius,
                    width: h.radius * 2,
                    height: h.radius * 2
                )
                ctx.strokeEllipse(in: rect)
            }
            ctx.setLineDash(phase: 0, lengths: [])

            // Measurements — dashed blue lines + label
            let measureColor = UIColor(red: 0.29, green: 0.62, blue: 0.90, alpha: 1)
            let measureFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
            ctx.setStrokeColor(measureColor.cgColor)
            ctx.setLineWidth(3)
            ctx.setLineDash(phase: 0, lengths: [10, 6])
            for m in payload.measurements {
                ctx.move(to: m.a)
                ctx.addLine(to: m.b)
                ctx.strokePath()
                measureColor.setFill()
                ctx.fillEllipse(in: CGRect(x: m.a.x - 6, y: m.a.y - 6, width: 12, height: 12))
                ctx.fillEllipse(in: CGRect(x: m.b.x - 6, y: m.b.y - 6, width: 12, height: 12))

                if let proj = payload.projection,
                   proj.contains(m.a), proj.contains(m.b) {
                    let cA = proj.pixelToLatLon(m.a)
                    let cB = proj.pixelToLatLon(m.b)
                    let meters = Geodesy.distance(cA, cB)
                    let nm = meters / 1852
                    let bearing = Geodesy.bearing(cA, cB)
                    let dist = nm >= 1
                        ? String(format: "%.2f nm", nm)
                        : String(format: "%d m", Int(meters.rounded()))
                    let label = "\(dist) · \(String(format: "%03d", Int(bearing.rounded())))°T" as NSString
                    let mid = CGPoint(x: (m.a.x + m.b.x) / 2, y: (m.a.y + m.b.y) / 2)
                    let textSize = label.size(withAttributes: [.font: measureFont])
                    let padX: CGFloat = 8, padY: CGFloat = 4
                    let box = CGRect(
                        x: mid.x - (textSize.width + padX * 2) / 2,
                        y: mid.y - (textSize.height + padY * 2) / 2,
                        width: textSize.width + padX * 2,
                        height: textSize.height + padY * 2
                    )
                    let path = UIBezierPath(roundedRect: box, cornerRadius: 6)
                    UIColor.white.withAlphaComponent(0.92).setFill()
                    path.fill()
                    measureColor.withAlphaComponent(0.4).setStroke()
                    path.lineWidth = 0.8
                    path.stroke()
                    label.draw(
                        at: CGPoint(x: box.minX + padX, y: box.minY + padY),
                        withAttributes: [
                            .font: measureFont,
                            .foregroundColor: UIColor(red: 0.10, green: 0.16, blue: 0.22, alpha: 1)
                        ]
                    )
                }
            }
            ctx.setLineDash(phase: 0, lengths: [])

            // NTMs — yellow label boxes
            let ntmFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
            for n in payload.ntms {
                let text = n.text as NSString
                let textSize = text.size(withAttributes: [.font: ntmFont])
                let padX: CGFloat = 10, padY: CGFloat = 6
                let boxSize = CGSize(width: textSize.width + padX * 2, height: textSize.height + padY * 2)
                let box = CGRect(
                    x: n.position.x - boxSize.width / 2,
                    y: n.position.y - boxSize.height / 2,
                    width: boxSize.width,
                    height: boxSize.height
                )
                let path = UIBezierPath(roundedRect: box, cornerRadius: 8)
                UIColor(red: 0.96, green: 0.78, blue: 0.26, alpha: 1).setFill()
                path.fill()
                UIColor(red: 0.10, green: 0.16, blue: 0.22, alpha: 0.4).setStroke()
                path.lineWidth = 1
                path.stroke()
                text.draw(
                    at: CGPoint(x: box.minX + padX, y: box.minY + padY),
                    withAttributes: [
                        .font: ntmFont,
                        .foregroundColor: UIColor(red: 0.10, green: 0.16, blue: 0.22, alpha: 1)
                    ]
                )
            }
        }
    }

    // MARK: - PDF page rendering

    private static func drawCoverPage(in bounds: CGRect, payload: ExportPayload) {
        let margin: CGFloat = 48
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: UIColor(red: 0.10, green: 0.16, blue: 0.22, alpha: 1)
        ]
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.gray
        ]

        let m = payload.metadata
        let route = "\(m.departurePort.isEmpty ? "—" : m.departurePort)  →  \(m.arrivalPort.isEmpty ? "—" : m.arrivalPort)"

        ("PASSAGE PLAN" as NSString).draw(
            at: CGPoint(x: margin, y: margin),
            withAttributes: titleAttrs
        )
        (route as NSString).draw(
            at: CGPoint(x: margin, y: margin + 38),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
        )

        var y: CGFloat = margin + 90

        func row(_ header: String, _ value: String) {
            (header as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            let v = value.isEmpty ? "—" : value
            (v as NSString).draw(at: CGPoint(x: margin + 160, y: y - 2), withAttributes: valueAttrs)
            y += 26
        }

        row("VESSEL", m.vesselName)
        row("IMO", m.imoNumber)
        row("CALLSIGN", m.callsign)
        row("CHART", m.chartNumber)

        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        row("DATE / TIME", df.string(from: m.voyageDate))

        y += 12
        row("PILOT", m.pilotName)
        row("LICENSE", m.pilotLicense)

        // Signature line
        y += 30
        let sigY = y
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.8)
        ctx.move(to: CGPoint(x: margin, y: sigY))
        ctx.addLine(to: CGPoint(x: margin + 280, y: sigY))
        ctx.strokePath()
        ("Pilot signature" as NSString).draw(
            at: CGPoint(x: margin, y: sigY + 4),
            withAttributes: footerAttrs
        )

        // Notes block
        if !m.notes.isEmpty {
            y = sigY + 50
            ("BRIEFING NOTES" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 18
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 3
            let notesAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black,
                .paragraphStyle: para
            ]
            let notesRect = CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 180)
            (m.notes as NSString).draw(in: notesRect, withAttributes: notesAttrs)
        }

        // Footer watermark
        ("NOT FOR NAVIGATION — Generated by Samudra (Wärtsilä Pilot PRO concept)" as NSString).draw(
            at: CGPoint(x: margin, y: bounds.height - margin),
            withAttributes: footerAttrs
        )

        let gen = DateFormatter()
        gen.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        let stamp = "Generated \(gen.string(from: payload.generatedAt))"
        let stampWidth = (stamp as NSString).size(withAttributes: footerAttrs).width
        (stamp as NSString).draw(
            at: CGPoint(x: bounds.width - margin - stampWidth, y: bounds.height - margin),
            withAttributes: footerAttrs
        )
    }

    private static func drawChartPage(in bounds: CGRect, chart: UIImage?, payload: ExportPayload) {
        let margin: CGFloat = 24
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]

        ("ANNOTATED CHART" as NSString).draw(
            at: CGPoint(x: margin, y: margin),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: UIColor.black
            ]
        )

        guard let chart else { return }

        let availableRect = CGRect(
            x: margin,
            y: margin + 30,
            width: bounds.width - margin * 2,
            height: bounds.height - margin * 2 - 60
        )

        // Aspect fit
        let chartAspect = chart.size.width / chart.size.height
        let availAspect = availableRect.width / availableRect.height
        var drawRect = availableRect
        if chartAspect > availAspect {
            // Letterbox vertically
            let height = availableRect.width / chartAspect
            drawRect = CGRect(
                x: availableRect.minX,
                y: availableRect.midY - height / 2,
                width: availableRect.width,
                height: height
            )
        } else {
            let width = availableRect.height * chartAspect
            drawRect = CGRect(
                x: availableRect.midX - width / 2,
                y: availableRect.minY,
                width: width,
                height: availableRect.height
            )
        }

        chart.draw(in: drawRect)

        // Legend
        let legendY = bounds.height - margin - 22
        ("Legend: " as NSString).draw(at: CGPoint(x: margin, y: legendY), withAttributes: headerAttrs)
        drawLegendDot(color: UIColor(red: 0.29, green: 0.62, blue: 0.90, alpha: 1),
                      label: "Route", at: CGPoint(x: margin + 60, y: legendY))
        drawLegendDot(color: UIColor(red: 0.90, green: 0.36, blue: 0.36, alpha: 1),
                      label: "Hazard", at: CGPoint(x: margin + 160, y: legendY))
        drawLegendDot(color: UIColor(red: 0.96, green: 0.78, blue: 0.26, alpha: 1),
                      label: "NTM", at: CGPoint(x: margin + 270, y: legendY))
    }

    private static func drawLegendDot(color: UIColor, label: String, at point: CGPoint) {
        let ctx = UIGraphicsGetCurrentContext()!
        color.setFill()
        ctx.fillEllipse(in: CGRect(x: point.x, y: point.y + 4, width: 10, height: 10))
        (label as NSString).draw(
            at: CGPoint(x: point.x + 16, y: point.y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.black
            ]
        )
    }

    private static func drawManifestPage(in bounds: CGRect, payload: ExportPayload) {
        let margin: CGFloat = 48
        var y: CGFloat = margin

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .heavy),
            .foregroundColor: UIColor.black
        ]
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor(red: 0.10, green: 0.16, blue: 0.22, alpha: 1)
        ]
        let itemAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.gray
        ]

        ("ANNOTATION MANIFEST" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: titleAttrs
        )
        y += 40

        ("Hazards (\(payload.hazards.count))" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: sectionAttrs
        )
        y += 22

        func coordString(_ p: CGPoint) -> String {
            guard let proj = payload.projection, proj.contains(p) else {
                return String(format: "(%.0f, %.0f) px", p.x, p.y)
            }
            return CoordinateFormatter.ddm(proj.pixelToLatLon(p))
        }

        if payload.hazards.isEmpty {
            ("— none —" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: itemAttrs)
            y += 18
        } else {
            for (i, h) in payload.hazards.enumerated() {
                let line = String(format: "%2d. %@   radius %.0f px",
                                  i + 1, coordString(h.center), h.radius)
                (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: itemAttrs)
                y += 18
                if y > bounds.height - margin - 30 { break }
            }
        }

        y += 12
        ("Notices to Mariner (\(payload.ntms.count))" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: sectionAttrs
        )
        y += 22

        if payload.ntms.isEmpty {
            ("— none —" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: itemAttrs)
            y += 18
        } else {
            for (i, n) in payload.ntms.enumerated() {
                let line = String(format: "%2d. %@ — %@",
                                  i + 1, coordString(n.position), n.text)
                (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: itemAttrs)
                y += 18
                if y > bounds.height - margin - 30 { break }
            }
        }

        y += 12
        ("Measurements (\(payload.measurements.count))" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: sectionAttrs
        )
        y += 22

        if payload.measurements.isEmpty {
            ("— none —" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: itemAttrs)
            y += 18
        } else {
            for (i, m) in payload.measurements.enumerated() {
                let label: String
                if let proj = payload.projection,
                   proj.contains(m.a), proj.contains(m.b) {
                    let cA = proj.pixelToLatLon(m.a)
                    let cB = proj.pixelToLatLon(m.b)
                    let meters = Geodesy.distance(cA, cB)
                    let nm = meters / 1852
                    let bearing = Geodesy.bearing(cA, cB)
                    let dist = nm >= 1
                        ? String(format: "%.2f nm", nm)
                        : String(format: "%d m", Int(meters.rounded()))
                    label = String(format: "%2d. %@ → %@ : %@ · %03d°T",
                                   i + 1,
                                   CoordinateFormatter.ddm(cA),
                                   CoordinateFormatter.ddm(cB),
                                   dist, Int(bearing.rounded()))
                } else {
                    label = String(format: "%2d. (%.0f, %.0f) → (%.0f, %.0f) px",
                                   i + 1, m.a.x, m.a.y, m.b.x, m.b.y)
                }
                (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: itemAttrs)
                y += 18
                if y > bounds.height - margin - 30 { break }
            }
        }

        let projectionNote = payload.projection == nil
            ? "Coordinates in chart-pixel space (no georef for this chart)."
            : "Coordinates in WGS84 DDM. Chart projected via UTM Zone 50 South."
        (projectionNote as NSString).draw(
            at: CGPoint(x: margin, y: bounds.height - margin),
            withAttributes: footerAttrs
        )
    }

    // MARK: - Filename helper

    static func suggestedFilename(_ payload: ExportPayload) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let stamp = formatter.string(from: payload.generatedAt)
        let vessel = payload.metadata.vesselName
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let prefix = vessel.isEmpty ? "Samudra" : vessel
        return "\(prefix)_\(stamp).\(payload.format.rawValue)"
    }

    // MARK: - Temp file helper

    static func tempURL(filename: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

// MARK: - CGSize Codable bridge

private struct CGSizeCodable: Codable {
    let width: CGFloat
    let height: CGFloat
}
