import SwiftUI

// MARK: - Arc-shaped capsule (banana/lens) Shape

struct ArcCapsule: Shape {
    let arcRadius: CGFloat       // center radius (mid-thickness)
    let thickness: CGFloat        // capsule thickness across arc
    let spanDegrees: Double       // total arc span in degrees

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let r1 = arcRadius - thickness / 2
        let r2 = arcRadius + thickness / 2
        let half = spanDegrees / 2 * .pi / 180
        let topA = -Double.pi / 2  // top of arc (SwiftUI y-down → -π/2 is up)
        let a1 = topA - half
        let a2 = topA + half
        // Virtual arc center: place so top of outer arc sits at rect.minY
        let cy = rect.minY + r2
        let center = CGPoint(x: cx, y: cy)

        // Outer arc — from left endpoint up over top to right endpoint
        let outerStart = CGPoint(x: cx + r2 * cos(a1), y: cy + r2 * sin(a1))
        path.move(to: outerStart)
        path.addArc(
            center: center,
            radius: r2,
            startAngle: .radians(a1),
            endAngle: .radians(a2),
            clockwise: false
        )

        // Right endcap (semicircle)
        let capRight = CGPoint(x: cx + arcRadius * cos(a2), y: cy + arcRadius * sin(a2))
        path.addArc(
            center: capRight,
            radius: thickness / 2,
            startAngle: .radians(a2),
            endAngle: .radians(a2 + .pi),
            clockwise: false
        )

        // Inner arc — back from right to left
        path.addArc(
            center: center,
            radius: r1,
            startAngle: .radians(a2),
            endAngle: .radians(a1),
            clockwise: true
        )

        // Left endcap
        let capLeft = CGPoint(x: cx + arcRadius * cos(a1), y: cy + arcRadius * sin(a1))
        path.addArc(
            center: capLeft,
            radius: thickness / 2,
            startAngle: .radians(a1 + .pi),
            endAngle: .radians(a1),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Arc tool menu

struct ArcToolMenu: View {
    let center: CGPoint               // pencil hover location (screen coords)
    let screenSize: CGSize
    @Binding var tool: ToolMode
    let onSelect: () -> Void

    // Geometry — tight, hugging pencil tip
    private let arcRadius: CGFloat = 88
    private let thickness: CGFloat = 48
    private let spanDegrees: Double = 110
    private let orbDiameter: CGFloat = 42

    private var halfSpanRad: Double { spanDegrees / 2 * .pi / 180 }
    private var r2: CGFloat { arcRadius + thickness / 2 }

    private var containerWidth: CGFloat {
        2 * (r2 * sin(halfSpanRad) + thickness / 2)
    }

    private var containerHeight: CGFloat {
        arcRadius * (1 - cos(halfSpanRad)) + thickness
    }

    private let edgePad: CGFloat = 24

    var body: some View {
        let modes = ToolMode.allCases

        ZStack {
            // Curved glass capsule
            ArcCapsule(arcRadius: arcRadius, thickness: thickness, spanDegrees: spanDegrees)
                .glassEffect(
                    .regular,
                    in: ArcCapsule(
                        arcRadius: arcRadius,
                        thickness: thickness,
                        spanDegrees: spanDegrees
                    )
                )

            // Buttons along arc centerline
            ForEach(Array(modes.enumerated()), id: \.element.id) { idx, mode in
                ToolOrb(mode: mode, active: tool == mode, diameter: orbDiameter) {
                    withAnimation(.snappy) {
                        tool = mode
                    }
                    onSelect()
                }
                .position(buttonPosition(index: idx, total: modes.count))
                .transition(
                    .scale(scale: 0.3, anchor: .center)
                        .combined(with: .opacity)
                        .animation(.bouncy.delay(Double(idx) * 0.04))
                )
            }
        }
        .frame(width: containerWidth, height: containerHeight)
        .position(clampedPosition())
    }

    private func buttonPosition(index: Int, total: Int) -> CGPoint {
        let cx = containerWidth / 2
        let cy = r2 // rect.minY + r2, with rect.minY = 0
        let half = halfSpanRad
        let topA = -Double.pi / 2
        let a1 = topA - half
        let a2 = topA + half
        let t = total > 1 ? Double(index) / Double(total - 1) : 0.5
        let angle = a1 + (a2 - a1) * t
        return CGPoint(
            x: cx + arcRadius * cos(angle),
            y: cy + arcRadius * sin(angle)
        )
    }

    /// Center the menu so virtual arc center sits at pencil location, clamped on-screen.
    private func clampedPosition() -> CGPoint {
        let halfW = containerWidth / 2
        let halfH = containerHeight / 2
        // Desired: ay = pencilY + halfH - r2 (virtual center at pencilY)
        var ax = center.x
        var ay = center.y + halfH - r2

        ax = min(max(ax, edgePad + halfW), screenSize.width - edgePad - halfW)
        ay = min(max(ay, edgePad + halfH), screenSize.height - edgePad - halfH)
        return CGPoint(x: ax, y: ay)
    }
}
