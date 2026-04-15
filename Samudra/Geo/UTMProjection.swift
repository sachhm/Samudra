// Samudra/Geo/UTMProjection.swift
import Foundation
import CoreGraphics

struct UTMProjection: Sendable {

    enum Hemisphere: String, Codable, Sendable { case north, south }

    // WGS84 ellipsoid
    private static let a: Double = 6_378_137.0           // semi-major axis (m)
    private static let f: Double = 1.0 / 298.257_223_563 // flattening
    private static let eSq: Double = 2 * f - f * f
    private static let ePrimeSq: Double = eSq / (1 - eSq)
    private static let k0: Double = 0.9996               // UTM scale factor
    private static let falseEasting: Double = 500_000.0
    private static let falseNorthing: Double = 10_000_000.0

    /// UTM coordinates (meters).
    struct UTM: Equatable, Sendable {
        let easting: Double
        let northing: Double
    }

    /// Forward Transverse Mercator: WGS84 lat/lon → UTM E/N.
    /// Snyder USGS Pub 1395 §8 equations 8-1 through 8-9.
    static func latLonToUTM(_ c: Coordinate, zone: Int, hemisphere: Hemisphere) -> UTM {
        let φ = c.lat * .pi / 180
        let λ = c.lon * .pi / 180
        let λ0 = (Double(6 * zone - 183)) * .pi / 180  // central meridian (rad)

        let sinφ = sin(φ)
        let cosφ = cos(φ)
        let tanφ = tan(φ)

        let N = a / sqrt(1 - eSq * sinφ * sinφ)
        let T = tanφ * tanφ
        let C = ePrimeSq * cosφ * cosφ
        let A = cosφ * (λ - λ0)

        // Pre-compute powers
        let eSq2 = eSq * eSq
        let eSq3 = eSq2 * eSq
        let T2 = T * T
        let C2 = C * C
        let A2 = A * A
        let A3 = A2 * A
        let A4 = A2 * A2
        let A5 = A4 * A
        let A6 = A4 * A2

        // M series — meridional arc
        let mCoef1 = 1.0 - eSq/4.0 - 3.0*eSq2/64.0 - 5.0*eSq3/256.0
        let mCoef2 = 3.0*eSq/8.0 + 3.0*eSq2/32.0 + 45.0*eSq3/1024.0
        let mCoef3 = 15.0*eSq2/256.0 + 45.0*eSq3/1024.0
        let mCoef4 = 35.0*eSq3/3072.0
        let m1 = mCoef1 * φ
        let m2 = mCoef2 * sin(2.0 * φ)
        let m3 = mCoef3 * sin(4.0 * φ)
        let m4 = mCoef4 * sin(6.0 * φ)
        let M = a * (m1 - m2 + m3 - m4)

        // x series
        let xCoef3 = 1.0 - T + C
        let xCoef5a = 5.0 - 18.0 * T
        let xCoef5b = T2 + 72.0 * C
        let xCoef5c = -58.0 * ePrimeSq
        let xCoef5 = xCoef5a + xCoef5b + xCoef5c
        let x3 = xCoef3 * A3 / 6.0
        let x5 = xCoef5 * A5 / 120.0
        let x = k0 * N * (A + x3 + x5)

        // y series
        let yCoef4 = 5.0 - T + 9.0 * C + 4.0 * C2
        let yCoef6a = 61.0 - 58.0 * T
        let yCoef6b = T2 + 600.0 * C
        let yCoef6c = -330.0 * ePrimeSq
        let yCoef6 = yCoef6a + yCoef6b + yCoef6c
        let y2 = A2 / 2.0
        let y4 = yCoef4 * A4 / 24.0
        let y6 = yCoef6 * A6 / 720.0
        let yBracket = y2 + y4 + y6
        let y = k0 * (M + N * tanφ * yBracket)

        let easting = x + falseEasting
        let northing = y + (hemisphere == .south ? falseNorthing : 0)
        return UTM(easting: easting, northing: northing)
    }

    /// Inverse Transverse Mercator: UTM E/N → WGS84 lat/lon.
    /// Snyder USGS Pub 1395 §8 equations 8-17 through 8-25.
    static func utmToLatLon(_ utm: UTM, zone: Int, hemisphere: Hemisphere) -> Coordinate {
        let x = utm.easting - falseEasting
        let y = utm.northing - (hemisphere == .south ? falseNorthing : 0)
        let λ0 = (Double(6 * zone - 183)) * .pi / 180

        // Pre-compute eSq powers
        let eSq2 = eSq * eSq
        let eSq3 = eSq2 * eSq

        let M = y / k0
        let muDenomCoef = 1.0 - eSq/4.0 - 3.0*eSq2/64.0 - 5.0*eSq3/256.0
        let mu = M / (a * muDenomCoef)

        let e1 = (1 - sqrt(1 - eSq)) / (1 + sqrt(1 - eSq))
        let e1Sq = e1 * e1
        let e1Cube = e1Sq * e1
        let e1Quad = e1Sq * e1Sq

        let phi1Coef1 = 3.0 * e1 / 2.0 - 27.0 * e1Cube / 32.0
        let phi1Coef2 = 21.0 * e1Sq / 16.0 - 55.0 * e1Quad / 32.0
        let phi1Coef3 = 151.0 * e1Cube / 96.0
        let phi1Coef4 = 1097.0 * e1Quad / 512.0
        let φ1 = mu
            + phi1Coef1 * sin(2.0 * mu)
            + phi1Coef2 * sin(4.0 * mu)
            + phi1Coef3 * sin(6.0 * mu)
            + phi1Coef4 * sin(8.0 * mu)

        let sinφ1 = sin(φ1)
        let cosφ1 = cos(φ1)
        let tanφ1 = tan(φ1)
        let sinφ1Sq = sinφ1 * sinφ1
        let cosφ1Sq = cosφ1 * cosφ1
        let tanφ1Sq = tanφ1 * tanφ1

        let C1 = ePrimeSq * cosφ1Sq
        let T1 = tanφ1Sq
        let C1Sq = C1 * C1
        let T1Sq = T1 * T1

        let N1Denom = sqrt(1.0 - eSq * sinφ1Sq)
        let N1 = a / N1Denom
        let R1Numer = a * (1.0 - eSq)
        let R1Denom = pow(1.0 - eSq * sinφ1Sq, 1.5)
        let R1 = R1Numer / R1Denom
        let D = x / (N1 * k0)

        let D2 = D * D
        let D3 = D2 * D
        let D4 = D2 * D2
        let D5 = D4 * D
        let D6 = D4 * D2

        // φ correction series
        let phiCoef4a = 5.0 + 3.0 * T1
        let phiCoef4b = 10.0 * C1 - 4.0 * C1Sq
        let phiCoef4c = -9.0 * ePrimeSq
        let phiCoef4 = phiCoef4a + phiCoef4b + phiCoef4c
        let phiCoef6a = 61.0 + 90.0 * T1
        let phiCoef6b = 298.0 * C1 + 45.0 * T1Sq
        let phiCoef6c = -252.0 * ePrimeSq - 3.0 * C1Sq
        let phiCoef6 = phiCoef6a + phiCoef6b + phiCoef6c
        let phiTerm2 = D2 / 2.0
        let phiTerm4 = phiCoef4 * D4 / 24.0
        let phiTerm6 = phiCoef6 * D6 / 720.0
        let phiCorrection = phiTerm2 - phiTerm4 + phiTerm6

        let φ = φ1 - (N1 * tanφ1 / R1) * phiCorrection

        // λ correction series
        let lamCoef3 = 1.0 + 2.0 * T1 + C1
        let lamCoef5a = 5.0 - 2.0 * C1 + 28.0 * T1
        let lamCoef5b = -3.0 * C1Sq + 8.0 * ePrimeSq + 24.0 * T1Sq
        let lamCoef5 = lamCoef5a + lamCoef5b
        let lamTerm3 = lamCoef3 * D3 / 6.0
        let lamTerm5 = lamCoef5 * D5 / 120.0
        let lamNumerator = D - lamTerm3 + lamTerm5
        let λ = λ0 + lamNumerator / cosφ1

        return Coordinate(lat: φ * 180 / .pi, lon: λ * 180 / .pi)
    }

    // MARK: - Instance API (bound to a georef)

    let zone: Int
    let hemisphere: Hemisphere
    private let pixelTL: CGPoint
    private let pixelBR: CGPoint
    private let utmTL: UTM
    private let utmBR: UTM
    private let pixelMinX: Double
    private let pixelMaxX: Double
    private let pixelMinY: Double
    private let pixelMaxY: Double

    init(georef: ChartGeoref) {
        switch georef.projection {
        case .utm(let z, let h):
            self.zone = z
            self.hemisphere = h
        }
        self.pixelTL = georef.pixelCorners.topLeft
        self.pixelBR = georef.pixelCorners.bottomRight
        self.utmTL = Self.latLonToUTM(georef.wgs84Corners.topLeft,
                                      zone: zone, hemisphere: hemisphere)
        self.utmBR = Self.latLonToUTM(georef.wgs84Corners.bottomRight,
                                      zone: zone, hemisphere: hemisphere)
        self.pixelMinX = min(pixelTL.x, pixelBR.x)
        self.pixelMaxX = max(pixelTL.x, pixelBR.x)
        self.pixelMinY = min(pixelTL.y, pixelBR.y)
        self.pixelMaxY = max(pixelTL.y, pixelBR.y)
    }

    /// Bilinear pixel ∈ pixel-rect → UTM E/N, then inverse TM → WGS84.
    func pixelToLatLon(_ pixel: CGPoint) -> Coordinate {
        let s = Double(pixel.x - pixelTL.x) / Double(pixelBR.x - pixelTL.x)
        let t = Double(pixel.y - pixelTL.y) / Double(pixelBR.y - pixelTL.y)
        let easting = utmTL.easting + s * (utmBR.easting - utmTL.easting)
        let northing = utmTL.northing + t * (utmBR.northing - utmTL.northing)
        return Self.utmToLatLon(
            UTM(easting: easting, northing: northing),
            zone: zone,
            hemisphere: hemisphere
        )
    }

    /// True iff pixel falls inside the projected chart area.
    func contains(_ pixel: CGPoint) -> Bool {
        Double(pixel.x) >= pixelMinX && Double(pixel.x) <= pixelMaxX
            && Double(pixel.y) >= pixelMinY && Double(pixel.y) <= pixelMaxY
    }
}
