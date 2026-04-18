import Testing
import Foundation
@testable import Samudra

@Suite struct ChartCatalogTests {
    @Test func loadsAllManifestEntries() {
        let charts = ChartCatalog.all
        #expect(charts.count == 3)
        #expect(charts.contains(where: { $0.id == "WA412" }))
        #expect(charts.contains(where: { $0.id == "WA001" }))
        #expect(charts.contains(where: { $0.id == "WA913" }))
    }

    @Test func eachChartHasGeoref() {
        for chart in ChartCatalog.all {
            #expect(chart.georef != nil, "chart \(chart.id) missing georef")
        }
    }

    @Test func defaultIsFirstInManifest() {
        #expect(ChartCatalog.default.id == "WA412")
    }
}
