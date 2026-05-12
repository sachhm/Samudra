import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var drawProgress: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 8
    @State private var waveBob: CGFloat = 0
    @State private var rootOpacity: Double = 1

    private let bgColor = Color(red: 0.71, green: 0.79, blue: 0.89)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("Samudra")
                    .font(.system(size: 56, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(2)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                ThreeWavesShape()
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 280, height: 64)
                    .offset(y: waveBob)
            }
        }
        .opacity(rootOpacity)
        .task { await runSequence() }
    }

    @MainActor
    private func runSequence() async {
        // Draw waves
        withAnimation(.easeInOut(duration: 1.4)) {
            drawProgress = 1
        }
        // Title fades in shortly after wave starts
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.easeOut(duration: 0.7)) {
            titleOpacity = 1
            titleOffset = 0
        }
        // Subtle bob loop
        try? await Task.sleep(nanoseconds: 800_000_000)
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            waveBob = -4
        }
        // Hold then fade
        try? await Task.sleep(nanoseconds: 900_000_000)
        withAnimation(.easeOut(duration: 0.6)) {
            rootOpacity = 0
        }
        try? await Task.sleep(nanoseconds: 600_000_000)
        onFinished()
    }
}

// MARK: - 3 wave shape (continuous line, 3 crests)

struct ThreeWavesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midY = h * 0.55
        let amp = h * 0.55

        // 3 evenly spaced crests
        let crests = 3
        let segW = w / CGFloat(crests)

        path.move(to: CGPoint(x: 0, y: midY))

        for i in 0..<crests {
            let xStart = CGFloat(i) * segW
            let xMid = xStart + segW / 2
            let xEnd = xStart + segW

            // Up to peak
            path.addCurve(
                to: CGPoint(x: xMid, y: midY - amp),
                control1: CGPoint(x: xStart + segW * 0.18, y: midY - amp * 0.2),
                control2: CGPoint(x: xMid - segW * 0.12, y: midY - amp * 1.05)
            )
            // Down to trough
            path.addCurve(
                to: CGPoint(x: xEnd, y: midY),
                control1: CGPoint(x: xMid + segW * 0.12, y: midY - amp * 1.05),
                control2: CGPoint(x: xEnd - segW * 0.18, y: midY - amp * 0.2)
            )
        }

        return path
    }
}

#Preview {
    SplashView(onFinished: {})
}
