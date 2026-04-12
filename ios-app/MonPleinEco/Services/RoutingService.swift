import Foundation
import MapKit

struct RouteResult {
    let polyline: MKPolyline
    let coordinates: [Coordinate]
    let distance: Double
    let duration: TimeInterval
}

enum RoutingService {
    static func calculateRoute(
        from start: Coordinate,
        to end: Coordinate,
        avoidTolls: Bool
    ) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.clLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.clLocation))
        request.transportType = .automobile
        if avoidTolls {
            request.tollPreference = .avoid
        }

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RoutingError.noRouteFound
        }

        let pointCount = route.polyline.pointCount
        let mapPoints = route.polyline.points()
        var coords: [Coordinate] = []
        for i in 0..<pointCount {
            let c = mapPoints[i].coordinate
            coords.append(Coordinate(lat: c.latitude, lon: c.longitude))
        }

        return RouteResult(
            polyline: route.polyline,
            coordinates: coords,
            distance: route.distance,
            duration: route.expectedTravelTime
        )
    }

    enum RoutingError: LocalizedError {
        case noRouteFound

        var errorDescription: String? {
            "Aucun itinéraire trouvé."
        }
    }
}
