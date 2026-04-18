import Foundation

struct ChartDocument: Identifiable {
    let id: String
    let code: String
    let displayName: String
    let resourceName: String
    let resourceExtension: String
    let georef: ChartGeoref?

    var bundleURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }
}

extension ChartDocument: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ChartDocument, rhs: ChartDocument) -> Bool { lhs.id == rhs.id }
}

// MARK: - Manifest decoding (private)

private struct ManifestEntry: Decodable {
    let id: String
    let code: String
    let displayName: String
    let pdf: String
    let georef: String
}

private struct Manifest: Decodable {
    let version: Int
    let charts: [ManifestEntry]
}

// MARK: - ChartCatalog

enum ChartCatalog {
    static let all: [ChartDocument] = loadCharts()
    static var `default`: ChartDocument { all.first! }

    /// Look up a chart by id; nil if not present.
    static func chart(id: String) -> ChartDocument? {
        all.first(where: { $0.id == id })
    }

    private static func loadCharts() -> [ChartDocument] {
        guard
            let manifestURL = Bundle.main.url(forResource: "manifest", withExtension: "json"),
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else {
            assertionFailure("manifest.json missing or malformed — add it to the Samudra/Charts/ group")
            return []
        }

        return manifest.charts.map { entry in
            let resourceName = (entry.pdf as NSString).deletingPathExtension
            let resourceExtension = (entry.pdf as NSString).pathExtension

            let georefName = (entry.georef as NSString).deletingPathExtension
            let georef: ChartGeoref? = {
                guard
                    let url = Bundle.main.url(forResource: georefName, withExtension: "json"),
                    let sidecarData = try? Data(contentsOf: url)
                else { return nil }
                return try? JSONDecoder().decode(ChartGeoref.self, from: sidecarData)
            }()

            return ChartDocument(
                id: entry.id,
                code: entry.code,
                displayName: entry.displayName,
                resourceName: resourceName,
                resourceExtension: resourceExtension,
                georef: georef
            )
        }
    }
}
