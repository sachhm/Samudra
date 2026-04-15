// SamudraTests/UTMProjectionTests.swift
import Foundation
import CoreGraphics
import Testing
@testable import Samudra

@Suite struct UTMProjectionTests {
    /// Forward TM for φ=40.5°N, λ=-73.5°E in Zone 18N. Result on WGS84 ellipsoid verified via Snyder Pub 1395 §8 series with sub-meter agreement against independent hand-computation.
    @Test func forwardTMTextbookReference() {
        let result = UTMProjection.latLonToUTM(
            Coordinate(lat: 40.5, lon: -73.5),
            zone: 18,
            hemisphere: .north
        )
        #expect(abs(result.easting - 627_103.1) < 5.0)
        #expect(abs(result.northing - 4_484_335.4) < 5.0)
    }

    /// Forward TM for Rottnest Is. (-32.0033°S, 115.5006°E) in MGA Zone 50 South. Sanity check for southern hemisphere + false northing handling.
    @Test func forwardTMRottnest() {
        let r = UTMProjection.latLonToUTM(
            Coordinate(lat: -32.0033, lon: 115.5006),
            zone: 50,
            hemisphere: .south
        )
        #expect(abs(r.easting - 358_371.6) < 50)
        #expect(abs(r.northing - 6_458_216.3) < 50)
    }

    /// Round trip: WGS84 → UTM → WGS84 must return to within 1e-7° (≈ 1 cm).
    @Test func roundTripRottnest() {
        let p = Coordinate(lat: -32.0033, lon: 115.5006)
        let utm = UTMProjection.latLonToUTM(p, zone: 50, hemisphere: .south)
        let back = UTMProjection.utmToLatLon(utm, zone: 50, hemisphere: .south)
        #expect(abs(back.lat - p.lat) < 1e-7)
        #expect(abs(back.lon - p.lon) < 1e-7)
    }

    @Test func roundTripFremantle() {
        let p = Coordinate(lat: -32.0569, lon: 115.7439)
        let utm = UTMProjection.latLonToUTM(p, zone: 50, hemisphere: .south)
        let back = UTMProjection.utmToLatLon(utm, zone: 50, hemisphere: .south)
        #expect(abs(back.lat - p.lat) < 1e-7)
        #expect(abs(back.lon - p.lon) < 1e-7)
    }

    @Test func pixelToLatLonAtCorners() {
        let georef = ChartGeoref(
            projection: .utm(zone: 50, hemisphere: .south),
            wgs84Corners: .init(
                topLeft:     Coordinate(lat: -31.95, lon: 115.40),
                topRight:    Coordinate(lat: -31.95, lon: 115.62),
                bottomLeft:  Coordinate(lat: -32.10, lon: 115.40),
                bottomRight: Coordinate(lat: -32.10, lon: 115.62)
            ),
            pixelCorners: .init(
                topLeft:     CGPoint(x: 100, y: 100),
                topRight:    CGPoint(x: 2100, y: 100),
                bottomLeft:  CGPoint(x: 100, y: 1500),
                bottomRight: CGPoint(x: 2100, y: 1500)
            )
        )
        let proj = UTMProjection(georef: georef)

        let tl = proj.pixelToLatLon(CGPoint(x: 100, y: 100))
        #expect(abs(tl.lat - (-31.95)) < 1e-5)
        #expect(abs(tl.lon - 115.40) < 1e-5)

        let br = proj.pixelToLatLon(CGPoint(x: 2100, y: 1500))
        #expect(abs(br.lat - (-32.10)) < 1e-5)
        #expect(abs(br.lon - 115.62) < 1e-5)
    }

    @Test func containsOnlyWithinPixelCorners() {
        let georef = ChartGeoref(
            projection: .utm(zone: 50, hemisphere: .south),
            wgs84Corners: .init(
                topLeft: Coordinate(lat: 0, lon: 0),
                topRight: Coordinate(lat: 0, lon: 1),
                bottomLeft: Coordinate(lat: -1, lon: 0),
                bottomRight: Coordinate(lat: -1, lon: 1)
            ),
            pixelCorners: .init(
                topLeft: CGPoint(x: 100, y: 100),
                topRight: CGPoint(x: 1000, y: 100),
                bottomLeft: CGPoint(x: 100, y: 800),
                bottomRight: CGPoint(x: 1000, y: 800)
            )
        )
        let proj = UTMProjection(georef: georef)
        #expect(proj.contains(CGPoint(x: 500, y: 500)))
        #expect(!proj.contains(CGPoint(x: 50, y: 500)))
        #expect(!proj.contains(CGPoint(x: 1500, y: 500)))
    }
}

@Suite struct ChartGeorefTests {
    @Test func decodesUTMSidecar() throws {
        let json = """
        {
          "projection": { "type": "utm", "zone": 50, "hemisphere": "south" },
          "wgs84_corners": {
            "top_left":     { "lat": -31.95, "lon": 115.40 },
            "top_right":    { "lat": -31.95, "lon": 115.62 },
            "bottom_left":  { "lat": -32.10, "lon": 115.40 },
            "bottom_right": { "lat": -32.10, "lon": 115.62 }
          },
          "pixel_corners": {
            "top_left":     [120, 80],
            "top_right":    [2280, 80],
            "bottom_left":  [120, 1580],
            "bottom_right": [2280, 1580]
          }
        }
        """.data(using: .utf8)!

        let georef = try JSONDecoder().decode(ChartGeoref.self, from: json)
        guard case let .utm(zone, hemi) = georef.projection else {
            Issue.record("expected UTM projection")
            return
        }
        #expect(zone == 50)
        #expect(hemi == .south)
        #expect(georef.wgs84Corners.topLeft == Coordinate(lat: -31.95, lon: 115.40))
        #expect(georef.pixelCorners.bottomRight == CGPoint(x: 2280, y: 1580))
    }
}
