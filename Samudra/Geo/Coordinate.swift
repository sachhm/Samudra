import Foundation

struct Coordinate: Hashable, Codable, Sendable {
    let lat: Double  // WGS84 latitude in degrees, [-90, 90]
    let lon: Double  // WGS84 longitude in degrees, [-180, 180]
}
