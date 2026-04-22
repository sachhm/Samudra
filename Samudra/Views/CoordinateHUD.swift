import SwiftUI

struct CoordinateHUDPill: View {
    let coordinate: Coordinate

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(CoordinateFormatter.ddm(coordinate))
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coordinates")
        .accessibilityValue(CoordinateFormatter.speech(coordinate))
    }
}
