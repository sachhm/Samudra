import Testing
@testable import Samudra

@Suite struct CoordinateFormatterTests {
    @Test func ddmSouthEast() {
        let c = Coordinate(lat: -32.04076, lon: 115.51867)
        // 32°02.4456′S 115°31.1202′E (rounded to 2 dp of minutes)
        #expect(CoordinateFormatter.ddm(c) == "32°02.45′S 115°31.12′E")
    }

    @Test func ddmNorthWest() {
        let c = Coordinate(lat: 51.4778, lon: -0.0014)
        #expect(CoordinateFormatter.ddm(c) == "51°28.67′N 000°00.08′W")
    }

    @Test func decimal() {
        let c = Coordinate(lat: -32.04076, lon: 115.51867)
        #expect(CoordinateFormatter.decimal(c) == "32.04076°S 115.51867°E")
    }

    @Test func speech() {
        let c = Coordinate(lat: -32.04076, lon: 115.51867)
        #expect(
            CoordinateFormatter.speech(c)
            == "32 degrees 2.45 minutes south, 115 degrees 31.12 minutes east"
        )
    }
}
