import SwiftUI

struct HazardAnnotation: Identifiable, Equatable, Codable {
    var id = UUID()
    var center: CGPoint
    var radius: CGFloat = 50

    func moved(to newCenter: CGPoint) -> HazardAnnotation {
        var copy = self
        copy.center = newCenter
        return copy
    }
}

/// Notice To Mariner (NTM)
struct NTMAnnotation: Identifiable, Equatable, Codable {
    var id = UUID()
    var position: CGPoint
    var text: String

    func moved(to newPosition: CGPoint) -> NTMAnnotation {
        var copy = self
        copy.position = newPosition
        return copy
    }

    func with(text newText: String) -> NTMAnnotation {
        var copy = self
        copy.text = newText
        return copy
    }
}

/// Two-point measurement on chart-pixel space; lat/lon + nm + bearing derived at render.
struct Measurement: Identifiable, Equatable, Codable {
    var id = UUID()
    var a: CGPoint
    var b: CGPoint

    func movedA(to newA: CGPoint) -> Measurement {
        var copy = self
        copy.a = newA
        return copy
    }

    func movedB(to newB: CGPoint) -> Measurement {
        var copy = self
        copy.b = newB
        return copy
    }
}
