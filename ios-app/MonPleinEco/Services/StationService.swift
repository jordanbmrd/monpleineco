import Foundation

actor StationService {
    static let shared = StationService()
    private init() {}

    func fetchStationsAround(
        points: [Coordinate],
        fuelIds: [Int],
        rangeMeters: Int = 9999
    ) async throws -> [Station] {
        let limitedPoints = Array(points.prefix(40))
        var stationsById: [Int: Station] = [:]
        var errors: [String] = []

        await withTaskGroup(of: Result<[Station], Error>.self) { group in
            for point in limitedPoints {
                group.addTask {
                    do {
                        let stations = try await self.fetchSingle(
                            point: point,
                            fuelIds: fuelIds,
                            rangeMeters: rangeMeters
                        )
                        return .success(stations)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(let stations):
                    for station in stations {
                        stationsById[station.id] = station
                    }
                case .failure(let error):
                    errors.append(error.localizedDescription)
                }
            }
        }

        if !errors.isEmpty && stationsById.isEmpty {
            throw StationError.fetchFailed(errors.prefix(3).joined(separator: "; "))
        }

        return Array(stationsById.values)
    }

    private func fetchSingle(
        point: Coordinate,
        fuelIds: [Int],
        rangeMeters: Int
    ) async throws -> [Station] {
        var components = URLComponents(
            string: "https://api.prix-carburants.2aaz.fr/stations/around/\(point.lat),\(point.lon)"
        )!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "responseFields", value: "Fuels,Price")
        ]
        if !fuelIds.isEmpty {
            queryItems.append(URLQueryItem(name: "fuels", value: fuelIds.map(String.init).joined(separator: ",")))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("m=0-\(rangeMeters)", forHTTPHeaderField: "Range")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else {
            throw StationError.badResponse
        }

        let apiStations = try JSONDecoder().decode([ApiStation].self, from: data)
        return apiStations.compactMap { $0.toStation() }
    }

    enum StationError: LocalizedError {
        case fetchFailed(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let details):
                return "Impossible de récupérer les stations. \(details)"
            case .badResponse:
                return "Réponse invalide du serveur."
            }
        }
    }
}
