import Testing
@testable import Samudra

@Suite struct GeodesyTests {
    /// Fremantle (32.0569°S, 115.7439°E) → Rottnest (32.0033°S, 115.5006°E)
    /// Haversine distance ≈ 23.7 km. Tolerance ±100 m.
    @Test func fremantleToRottnestDistance() {
        let fremantle = Coordinate(lat: -32.0569, lon: 115.7439)
        let rottnest  = Coordinate(lat: -32.0033, lon: 115.5006)
        let d = Geodesy.distance(fremantle, rottnest)
        #expect(abs(d - 23_697) < 100)
    }

    @Test func zeroDistanceForSamePoint() {
        let c = Coordinate(lat: 10, lon: 20)
        #expect(Geodesy.distance(c, c) == 0)
    }

    /// Bearing from Fremantle (32.0569°S, 115.7439°E) due-west to a point at
    /// (32.0569°S, 115.5006°E) should be ≈ 270°T.
    @Test func dueWestBearingIs270() {
        let a = Coordinate(lat: -32.0569, lon: 115.7439)
        let b = Coordinate(lat: -32.0569, lon: 115.5006)
        let θ = Geodesy.bearing(a, b)
        #expect(abs(θ - 270) < 0.5)
    }

    @Test func dueNorthBearingIs0() {
        let a = Coordinate(lat: -32, lon: 115)
        let b = Coordinate(lat: -31, lon: 115)
        let θ = Geodesy.bearing(a, b)
        #expect(abs(θ - 0) < 0.01 || abs(θ - 360) < 0.01)
    }

    @Test func dueEastBearingIs90() {
        let a = Coordinate(lat: -32, lon: 115)
        let b = Coordinate(lat: -32, lon: 116)
        #expect(abs(Geodesy.bearing(a, b) - 90) < 0.5)
    }
}
