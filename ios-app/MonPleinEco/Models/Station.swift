import Foundation
import CoreLocation

struct Coordinate: Codable, Hashable {
    let lat: Double
    let lon: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct StationFuel: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String
    let available: Bool
    let price: Double?
    let updatedAt: String?

    var fuelType: FuelType? {
        FuelType(rawValue: id)
    }
}

struct Station: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let brand: String?
    let address: String?
    let city: String?
    let coordinates: Coordinate
    let fuels: [StationFuel]
}

struct StationWithMetrics: Identifiable, Hashable {
    let station: Station
    let bestPrice: Double
    let bestFuelLabel: String
    let distanceToRoute: Double
    var rank: Int

    var id: Int { station.id }
}

// MARK: - API response mapping

struct ApiStationFuel: Decodable {
    let id: Int?
    let name: String?
    let shortName: String?
    let available: Bool?
    let Price: ApiPrice?
    let Update: ApiUpdate?

    struct ApiPrice: Decodable {
        let value: Double?
    }

    struct ApiUpdate: Decodable {
        let value: String?
    }
}

struct ApiStation: Decodable {
    let id: Int
    let name: String?
    let Brand: ApiBrand?
    let Address: ApiAddress?
    let Coordinates: ApiCoordinates?
    let Fuels: [ApiStationFuel]?

    struct ApiBrand: Decodable {
        let name: String?
    }

    struct ApiAddress: Decodable {
        let street_line: String?
        let city_line: String?
    }

    struct ApiCoordinates: Decodable {
        let latitude: Double?
        let longitude: Double?
    }

    func toStation() -> Station? {
        guard let coords = Coordinates,
              let lat = coords.latitude,
              let lon = coords.longitude else {
            return nil
        }

        let mappedFuels = (Fuels ?? []).map { fuel in
            StationFuel(
                id: fuel.id ?? 0,
                name: fuel.name ?? "Carburant",
                shortName: fuel.shortName ?? "—",
                available: fuel.available ?? false,
                price: fuel.Price?.value,
                updatedAt: fuel.Update?.value
            )
        }

        return Station(
            id: id,
            name: name ?? "Station",
            brand: Brand?.name,
            address: Address?.street_line,
            city: Address?.city_line,
            coordinates: Coordinate(lat: lat, lon: lon),
            fuels: mappedFuels
        )
    }
}
