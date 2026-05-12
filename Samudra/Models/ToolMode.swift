import SwiftUI

enum ToolMode: String, CaseIterable, Identifiable {
    case route
    case hazard
    case note
    case eraser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .route: "Plot Route"
        case .hazard: "Mark Hazard"
        case .note: "Add Note"
        case .eraser: "Eraser"
        }
    }

    var symbol: String {
        switch self {
        case .route: "scribble.variable"
        case .hazard: "exclamationmark.triangle.fill"
        case .note: "text.bubble.fill"
        case .eraser: "eraser.fill"
        }
    }

    var tint: Color {
        switch self {
        case .route: ChartPalette.routeBlue
        case .hazard: ChartPalette.hazardRed
        case .note: ChartPalette.noteYellow
        case .eraser: ChartPalette.textSecondary
        }
    }

    var usesPencilKit: Bool {
        self == .route || self == .eraser
    }
}

enum ChartPalette {
    static let navy = Color(red: 0x1B/255, green: 0x28/255, blue: 0x38/255)
    static let surface = Color(red: 0x24/255, green: 0x34/255, blue: 0x47/255)
    static let routeBlue = Color(red: 0x4A/255, green: 0x9F/255, blue: 0xE5/255)
    static let hazardRed = Color(red: 0xE5/255, green: 0x5C/255, blue: 0x5C/255)
    static let noteYellow = Color(red: 0xF5/255, green: 0xC8/255, blue: 0x42/255)
    static let textPrimary = Color(red: 0xE8/255, green: 0xEC/255, blue: 0xF0/255)
    static let textSecondary = Color(red: 0x88/255, green: 0x99/255, blue: 0xAA/255)
    static let border = Color(red: 0x2F/255, green: 0x40/255, blue: 0x50/255)
}
