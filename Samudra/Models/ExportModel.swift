import Foundation
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case png
    case pdf
    case json   // raw annotation data (for handoff to other bridge systems)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .png: "PNG Image"
        case .pdf: "PDF Briefing"
        case .json: "Annotation Data (JSON)"
        }
    }

    var symbol: String {
        switch self {
        case .png: "photo"
        case .pdf: "doc.richtext"
        case .json: "curlybraces"
        }
    }
}

struct VoyageMetadata: Equatable, Codable {
    var vesselName: String = ""
    var callsign: String = ""
    var imoNumber: String = ""
    var pilotName: String = ""
    var pilotLicense: String = ""
    var departurePort: String = ""
    var arrivalPort: String = ""
    var chartNumber: String = ""
    var voyageDate: Date = .now
    var notes: String = ""

    static let empty = VoyageMetadata()
}

struct ExportPayload {
    let metadata: VoyageMetadata
    let format: ExportFormat
    let chartImage: UIImage
    let chartSize: CGSize
    let drawingPNG: UIImage?
    let hazards: [HazardAnnotation]
    let ntms: [NTMAnnotation]
    let generatedAt: Date
}

struct ExportResult {
    let fileURL: URL
    let preview: UIImage?
    let suggestedFilename: String
}
