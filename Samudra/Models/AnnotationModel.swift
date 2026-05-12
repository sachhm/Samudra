import SwiftUI

struct HazardAnnotation: Identifiable, Equatable {
    let id = UUID()
    var center: CGPoint
    var radius: CGFloat = 50

    func moved(to newCenter: CGPoint) -> HazardAnnotation {
        var copy = self
        copy.center = newCenter
        return copy
    }
}

/// Notice To Mariner (NTM)
struct NTMAnnotation: Identifiable, Equatable {
    let id = UUID()
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
