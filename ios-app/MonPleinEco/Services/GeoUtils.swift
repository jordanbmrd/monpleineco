import Foundation

enum GeoUtils {
    private static let earthRadius: Double = 6_371_000

    static func haversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let dLat = toRad(b.lat - a.lat)
        let dLon = toRad(b.lon - a.lon)
        let lat1 = toRad(a.lat)
        let lat2 = toRad(b.lat)

        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        let h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(1 - h))
    }

    static func distancePointToSegmentMeters(
        point: Coordinate,
        segStart: Coordinate,
        segEnd: Coordinate
    ) -> Double {
        let refLat = (segStart.lat + segEnd.lat) / 2
        let p = project(point, refLat: refLat)
        let a = project(segStart, refLat: refLat)
        let b = project(segEnd, refLat: refLat)

        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y
        let abLenSq = abx * abx + aby * aby
        let t = abLenSq == 0 ? 0 : (apx * abx + apy * aby) / abLenSq
        let clamped = max(0, min(1, t))

        let closestX = a.x + clamped * abx
        let closestY = a.y + clamped * aby
        let dx = p.x - closestX
        let dy = p.y - closestY
        return sqrt(dx * dx + dy * dy)
    }

    static func distancePointToPolylineMeters(
        point: Coordinate,
        polyline: [Coordinate]
    ) -> Double {
        guard polyline.count >= 2 else { return .infinity }
        var minDist = Double.infinity
        for i in 0..<(polyline.count - 1) {
            let d = distancePointToSegmentMeters(
                point: point,
                segStart: polyline[i],
                segEnd: polyline[i + 1]
            )
            if d < minDist { minDist = d }
        }
        return minDist
    }

    static func sampleRoutePoints(
        coordinates: [Coordinate],
        spacingMeters: Double
    ) -> [Coordinate] {
        guard coordinates.count > 1 else { return coordinates }

        var sampled: [Coordinate] = [coordinates[0]]
        var accumulator: Double = 0
        var last = coordinates[0]

        for i in 1..<coordinates.count {
            let current = coordinates[i]
            let segmentDist = haversineMeters(last, current)
            accumulator += segmentDist
            if accumulator >= spacingMeters {
                sampled.append(current)
                accumulator = 0
            }
            last = current
        }

        let tail = coordinates[coordinates.count - 1]
        if let lastSample = sampled.last,
           lastSample.lat != tail.lat || lastSample.lon != tail.lon {
            sampled.append(tail)
        }
        return sampled
    }

    // MARK: - Private

    private static func toRad(_ deg: Double) -> Double {
        deg * .pi / 180
    }

    private struct Point2D {
        let x: Double
        let y: Double
    }

    private static func project(_ coord: Coordinate, refLat: Double) -> Point2D {
        let latRad = toRad(coord.lat)
        let lonRad = toRad(coord.lon)
        let refLatRad = toRad(refLat)
        return Point2D(
            x: earthRadius * lonRad * cos(refLatRad),
            y: earthRadius * latRad
        )
    }
}
