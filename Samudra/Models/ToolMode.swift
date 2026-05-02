import SwiftUI

enum ToolMode: String, CaseIterable, Identifiable {
    case draw
    case hazard
    case note
    case measure
    case eraser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draw: "Draw"
        case .hazard: "Hazard"
        case .note: "Note"
        case .measure: "Measure"
        case .eraser: "Erase"
        }
    }

    var symbol: String {
        switch self {
        case .draw: "pencil.tip"
        case .hazard: "exclamationmark.triangle"
        case .note: "mappin"
        case .measure: "ruler"
        case .eraser: "eraser"
        }
    }

    var symbolFilled: String {
        switch self {
        case .draw: "pencil.tip"
        case .hazard: "exclamationmark.triangle.fill"
        case .note: "mappin.circle.fill"
        case .measure: "ruler.fill"
        case .eraser: "eraser.fill"
        }
    }

    var tint: Color {
        switch self {
        case .draw: ChartPalette.routeBlue
        case .hazard: ChartPalette.hazardRed
        case .note: ChartPalette.noteYellow
        case .measure: Color(uiColor: .systemTeal)
        case .eraser: ChartPalette.textSecondary
        }
    }

    var usesPencilKit: Bool {
        self == .draw
    }
}

enum ChartPalette {
    static let navy = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let surfaceHi = Color(uiColor: .tertiarySystemBackground)
    static let routeBlue = Color(uiColor: .systemBlue)
    static let hazardRed = Color(uiColor: .systemRed)
    static let noteYellow = Color(uiColor: .systemOrange)
    static let okGreen = Color(uiColor: .systemGreen)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let border = Color(uiColor: .separator)
}
