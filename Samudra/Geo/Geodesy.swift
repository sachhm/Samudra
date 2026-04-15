import Foundation

enum Geodesy {
    /// Mean Earth radius (meters), WGS84.
    static let earthRadius: Double = 6_371_008.8

    /// Great-circle distance in meters via haversine.
    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = a.lat * .pi / 180
        let φ2 = b.lat * .pi / 180
        let Δφ = (b.lat - a.lat) * .pi / 180
        let Δλ = (b.lon - a.lon) * .pi / 180
        let h = sin(Δφ / 2) * sin(Δφ / 2)
              + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * earthRadius * atan2(sqrt(h), sqrt(1 - h))
    }

    /// Initial bearing in degrees true, range [0, 360).
    static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = a.lat * .pi / 180
        let φ2 = b.lat * .pi / 180
        let Δλ = (b.lon - a.lon) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(y, x) * 180 / .pi
        return (θ + 360).truncatingRemainder(dividingBy: 360)
    }
}
