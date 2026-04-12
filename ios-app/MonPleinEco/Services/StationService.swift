import Foundation
import OSLog

actor StationService {
    static let shared = StationService()

    private let cache = StationCache()

    private init() {}

    func fetchStationsAround(
        points: [Coordinate],
        fuelIds: [Int],
        rangeMeters: Int = 9999
    ) async throws -> [Station] {
        let limitedPoints = Array(points.prefix(40))
        AppLog.stations.debug("fetchStationsAround points=\(limitedPoints.count) fuelIds=\(fuelIds.map(String.init).joined(separator: ",")) rangeM=\(rangeMeters)")

        var stationsById: [Int: Station] = [:]
        var errors: [String] = []

        await withTaskGroup(of: Result<[Station], Error>.self) { group in
            for point in limitedPoints {
                group.addTask {
                    do {
                        let stations = try await self.fetchSingleCached(
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

        AppLog.stations.debug("fetchStationsAround merged unique=\(stationsById.count) taskErrors=\(errors.count)")
        if !errors.isEmpty {
            AppLog.stations.warning("fetchStationsAround errors sample: \(errors.prefix(5).joined(separator: " | "), privacy: .public)")
        }

        if !errors.isEmpty && stationsById.isEmpty {
            throw StationError.fetchFailed(errors.prefix(3).joined(separator: "; "))
        }

        return Array(stationsById.values)
    }

    // MARK: - Cached fetch

    private func fetchSingleCached(
        point: Coordinate,
        fuelIds: [Int],
        rangeMeters: Int
    ) async throws -> [Station] {
        let cacheKey = StationCache.key(point: point, fuelIds: fuelIds, range: rangeMeters)

        if let cached = await cache.get(cacheKey) {
            AppLog.stations.debug("cache HIT key=\(cacheKey)")
            return cached
        }

        let stations = try await fetchSingle(point: point, fuelIds: fuelIds, rangeMeters: rangeMeters)
        await cache.set(cacheKey, stations: stations)
        return stations
    }

    // MARK: - Network

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

        guard let urlString = components.url?.absoluteString else {
            AppLog.stations.error("fetchSingle URL invalide")
            throw StationError.badResponse
        }
        AppLog.stations.debug("fetchSingle GET \(urlString, privacy: .public)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            AppLog.stations.error("fetchSingle network error: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.stations.debug("fetchSingle HTTP \(status) dataBytes=\(data.count)")

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else {
            let bodyPreview = String(data: data.prefix(200), encoding: .utf8) ?? ""
            AppLog.stations.error("fetchSingle bad status \(status) bodyPrefix=\(bodyPreview, privacy: .public)")
            throw StationError.badResponse
        }

        let apiStations: [ApiStation]
        do {
            apiStations = try JSONDecoder().decode([ApiStation].self, from: data)
        } catch {
            AppLog.stations.error("fetchSingle JSON decode failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        let mapped = apiStations.compactMap { $0.toStation() }
        if mapped.count != apiStations.count {
            AppLog.stations.warning("fetchSingle mapped=\(mapped.count) raw=\(apiStations.count) (certaines stations sans coordonnées)")
        }
        return mapped
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

// MARK: - Station Cache

/// In-memory + disk cache for station API responses. TTL = 6 hours.
actor StationCache {
    private static let ttl: TimeInterval = 6 * 3600
    private static let diskFolder = "station_cache"

    private var memory: [String: CacheEntry] = [:]

    private struct CacheEntry {
        let stations: [Station]
        let date: Date
        var isValid: Bool { Date().timeIntervalSince(date) < StationCache.ttl }
    }

    /// Rounds coordinates to ~1 km grid to maximize cache hits for nearby queries
    static func key(point: Coordinate, fuelIds: [Int], range: Int) -> String {
        let lat = (point.lat * 100).rounded() / 100
        let lon = (point.lon * 100).rounded() / 100
        let fuels = fuelIds.sorted().map(String.init).joined(separator: "-")
        return "\(lat)_\(lon)_\(fuels)_\(range)"
    }

    func get(_ key: String) -> [Station]? {
        if let entry = memory[key], entry.isValid {
            return entry.stations
        }
        memory[key] = nil

        if let entry = loadFromDisk(key), entry.isValid {
            memory[key] = entry
            return entry.stations
        }
        return nil
    }

    func set(_ key: String, stations: [Station]) {
        let entry = CacheEntry(stations: stations, date: Date())
        memory[key] = entry
        saveToDisk(key, entry: entry)
    }

    // MARK: - Disk persistence

    private var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.diskFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for key: String) -> URL {
        let safe = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent(safe + ".json")
    }

    private struct DiskEntry: Codable {
        let stations: [Station]
        let date: Date
    }

    private func saveToDisk(_ key: String, entry: CacheEntry) {
        let disk = DiskEntry(stations: entry.stations, date: entry.date)
        if let data = try? JSONEncoder().encode(disk) {
            try? data.write(to: fileURL(for: key), options: .atomic)
        }
    }

    private func loadFromDisk(_ key: String) -> CacheEntry? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let disk = try? JSONDecoder().decode(DiskEntry.self, from: data) else {
            return nil
        }
        return CacheEntry(stations: disk.stations, date: disk.date)
    }
}
