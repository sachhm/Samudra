import SwiftUI

struct ScaleBarView: View {
    let metersPerScreenPoint: Double  // current physical scale at this zoom

    /// Candidate lengths in meters (round nautical/metric values), ascending.
    private static let candidates: [Double] = [
        100, 250, 500, 1000, 2000, 5000,
        1852 * 0.5,   // 0.5 nm
        1852,         // 1 nm
        1852 * 2,
        1852 * 5,
        1852 * 10,
        1852 * 20
    ]

    private var chosen: (meters: Double, screenWidth: Double) {
        guard metersPerScreenPoint > 0 else {
            return (Self.candidates.first ?? 100, 80)
        }
        let target: Double = 100
        let withWidths = Self.candidates.map { ($0, $0 / metersPerScreenPoint) }
        let inRange = withWidths.filter { $0.1 <= 120 }
        if let pick = inRange.min(by: { abs($0.1 - target) < abs($1.1 - target) }) {
            return pick
        }
        return withWidths.first ?? (100, 80)
    }

    var body: some View {
        let (meters, width) = chosen
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.6))
                    .frame(width: width, height: 6)
                HStack(spacing: 0) {
                    Rectangle().fill(Color(uiColor: .label))
                    Rectangle().fill(Color(uiColor: .systemBackground))
                }
                .frame(width: width, height: 6)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(uiColor: .label).opacity(0.8), lineWidth: 0.5))
            }
            Text(label(for: meters))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scale: \(label(for: meters))")
    }

    private func label(for meters: Double) -> String {
        if meters >= 1852 {
            let nm = meters / 1852
            return nm == nm.rounded() ? "\(Int(nm)) nm" : String(format: "%.1f nm", nm)
        } else if meters >= 1000 {
            let km = meters / 1000
            return km == km.rounded() ? "\(Int(km)) km" : String(format: "%.1f km", km)
        } else {
            return "\(Int(meters)) m"
        }
    }
}
