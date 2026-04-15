import Testing
@testable import Samudra

@Suite struct CoordinateTests {
    @Test func storesLatitudeAndLongitude() {
        let c = Coordinate(lat: -32.0, lon: 115.5)
        #expect(c.lat == -32.0)
        #expect(c.lon == 115.5)
    }

    @Test func isEquatable() {
        #expect(Coordinate(lat: 1, lon: 2) == Coordinate(lat: 1, lon: 2))
        #expect(Coordinate(lat: 1, lon: 2) != Coordinate(lat: 1, lon: 3))
    }
}
