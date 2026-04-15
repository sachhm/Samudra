import Foundation

enum CoordinateFormatter {
    /// "32°02.45′S 115°31.12′E"
    static func ddm(_ c: Coordinate) -> String {
        let (latDeg, latMin) = ddmComponents(c.lat)
        let (lonDeg, lonMin) = ddmComponents(c.lon)
        let latHemi = c.lat >= 0 ? "N" : "S"
        let lonHemi = c.lon >= 0 ? "E" : "W"
        return String(
            format: "%02d°%05.2f′%@ %03d°%05.2f′%@",
            latDeg, latMin, latHemi, lonDeg, lonMin, lonHemi
        )
    }

    /// "32.04076°S 115.51867°E"
    static func decimal(_ c: Coordinate) -> String {
        let latHemi = c.lat >= 0 ? "N" : "S"
        let lonHemi = c.lon >= 0 ? "E" : "W"
        return String(
            format: "%.5f°%@ %.5f°%@",
            abs(c.lat), latHemi, abs(c.lon), lonHemi
        )
    }

    /// "32 degrees 2.45 minutes south, 115 degrees 31.12 minutes east"
    static func speech(_ c: Coordinate) -> String {
        let (latDeg, latMin) = ddmComponents(c.lat)
        let (lonDeg, lonMin) = ddmComponents(c.lon)
        let latHemi = c.lat >= 0 ? "north" : "south"
        let lonHemi = c.lon >= 0 ? "east" : "west"
        return String(
            format: "%d degrees %.2f minutes %@, %d degrees %.2f minutes %@",
            latDeg, latMin, latHemi, lonDeg, lonMin, lonHemi
        )
    }

    private static func ddmComponents(_ value: Double) -> (deg: Int, min: Double) {
        let v = abs(value)
        let deg = Int(v.rounded(.down))
        let min = (v - Double(deg)) * 60
        return (deg, min)
    }
}
