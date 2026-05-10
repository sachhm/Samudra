import Testing
import Foundation
@testable import Samudra

@Suite struct ChartCatalogTests {
    @Test func loadsFullWACatalogue() {
        let charts = ChartCatalog.all
        #expect(charts.count >= 50, "expected full WA catalogue (~54 charts), got \(charts.count)")
        // Spot-check the three originally-bundled charts are present (by filename stem).
        #expect(charts.contains(where: { $0.id == "WA412_rottnest_island" }))
        #expect(charts.contains(where: { $0.id == "WA001_ocean_reef_to_cape_peron" }))
        #expect(charts.contains(where: { $0.id == "WA913_cape_peron_to_dawesville" }))
    }

    @Test func eachChartHasGeoref() {
        for chart in ChartCatalog.all {
            #expect(chart.georef != nil, "chart \(chart.id) missing georef")
        }
    }

    @Test func defaultPrefersRottnest() {
        // Rottnest Island has a bundled PDF + recognisable name, pinned as default.
        #expect(ChartCatalog.default.id == "WA412_rottnest_island")
    }
}
