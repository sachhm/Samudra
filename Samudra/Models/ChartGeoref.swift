import Foundation
import CoreGraphics

struct ChartGeoref: Codable, Sendable {

    enum Projection: Codable, Sendable, Equatable {
        case utm(zone: Int, hemisphere: UTMProjection.Hemisphere)

        private enum CodingKeys: String, CodingKey { case type, zone, hemisphere }
        private enum Kind: String, Codable { case utm }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(Kind.self, forKey: .type)
            switch kind {
            case .utm:
                let zone = try c.decode(Int.self, forKey: .zone)
                let hemi = try c.decode(UTMProjection.Hemisphere.self, forKey: .hemisphere)
                self = .utm(zone: zone, hemisphere: hemi)
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .utm(let zone, let hemi):
                try c.encode(Kind.utm, forKey: .type)
                try c.encode(zone, forKey: .zone)
                try c.encode(hemi, forKey: .hemisphere)
            }
        }
    }

    struct Corners: Codable, Sendable, Equatable {
        let topLeft: Coordinate
        let topRight: Coordinate
        let bottomLeft: Coordinate
        let bottomRight: Coordinate

        private enum CodingKeys: String, CodingKey {
            case topLeft = "top_left"
            case topRight = "top_right"
            case bottomLeft = "bottom_left"
            case bottomRight = "bottom_right"
        }
    }

    struct PixelCorners: Codable, Sendable, Equatable {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint

        init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomLeft = bottomLeft
            self.bottomRight = bottomRight
        }

        private enum CodingKeys: String, CodingKey {
            case topLeft = "top_left"
            case topRight = "top_right"
            case bottomLeft = "bottom_left"
            case bottomRight = "bottom_right"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.topLeft = try Self.decodePoint(c, .topLeft)
            self.topRight = try Self.decodePoint(c, .topRight)
            self.bottomLeft = try Self.decodePoint(c, .bottomLeft)
            self.bottomRight = try Self.decodePoint(c, .bottomRight)
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try Self.encodePoint(&c, .topLeft, topLeft)
            try Self.encodePoint(&c, .topRight, topRight)
            try Self.encodePoint(&c, .bottomLeft, bottomLeft)
            try Self.encodePoint(&c, .bottomRight, bottomRight)
        }

        private static func decodePoint(
            _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
        ) throws -> CGPoint {
            var arr = try c.nestedUnkeyedContainer(forKey: key)
            let x = try arr.decode(Double.self)
            let y = try arr.decode(Double.self)
            return CGPoint(x: x, y: y)
        }

        private static func encodePoint(
            _ c: inout KeyedEncodingContainer<CodingKeys>, _ key: CodingKeys, _ p: CGPoint
        ) throws {
            var arr = c.nestedUnkeyedContainer(forKey: key)
            try arr.encode(Double(p.x))
            try arr.encode(Double(p.y))
        }
    }

    let projection: Projection
    let wgs84Corners: Corners
    let pixelCorners: PixelCorners

    private enum CodingKeys: String, CodingKey {
        case projection
        case wgs84Corners = "wgs84_corners"
        case pixelCorners = "pixel_corners"
    }
}
