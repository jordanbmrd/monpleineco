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

        let raw = Array(stationsById.values)
        return await enrichWithOsm(raw)
    }

    // MARK: - OSM enrichment
    //
    // The official government dataset does not carry brand/name fields.
    // We complement it with OpenStreetMap (`amenity=fuel` features carry
    // `brand`, `name`, `operator` tags) via the Overpass API. Each station
    // is matched to the closest OSM fuel feature within a tolerance, since
    // the government coordinates are rounded.

    private static let overpassURL = URL(string: "https://overpass-api.de/api/interpreter")!
    private static let osmMatchRadiusM: Double = 250
    private static let osmBboxPaddingDeg = 0.005

    private func enrichWithOsm(_ stations: [Station]) async -> [Station] {
        guard !stations.isEmpty else { return stations }

        let lats = stations.map { $0.coordinates.lat }
        let lons = stations.map { $0.coordinates.lon }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return stations
        }

        let south = minLat - Self.osmBboxPaddingDeg
        let north = maxLat + Self.osmBboxPaddingDeg
        let west = minLon - Self.osmBboxPaddingDeg
        let east = maxLon + Self.osmBboxPaddingDeg
        let bbox = "\(south),\(west),\(north),\(east)"
        let query =
            "[out:json][timeout:25];" +
            "(node[\"amenity\"=\"fuel\"](\(bbox));way[\"amenity\"=\"fuel\"](\(bbox)););" +
            "out center tags;"

        var request = URLRequest(url: Self.overpassURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MonPleinEco/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)
        request.httpBody = body.data(using: .utf8)

        let elements: [OverpassElement]
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                AppLog.stations.warning("OSM enrichment HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return stations
            }
            let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
            elements = decoded.elements ?? []
        } catch {
            AppLog.stations.warning("OSM enrichment failed: \(error.localizedDescription, privacy: .public)")
            return stations
        }

        struct OsmPoint { let coord: Coordinate; let tags: [String: String] }
        let osm: [OsmPoint] = elements.compactMap { el in
            let lat = el.lat ?? el.center?.lat
            let lon = el.lon ?? el.center?.lon
            guard let lat, let lon else { return nil }
            return OsmPoint(coord: Coordinate(lat: lat, lon: lon), tags: el.tags ?? [:])
        }
        guard !osm.isEmpty else { return stations }

        return stations.map { station -> Station in
            var bestDist = Double.infinity
            var bestTags: [String: String]? = nil
            for point in osm {
                let d = GeoUtils.haversineMeters(station.coordinates, point.coord)
                if d < bestDist {
                    bestDist = d
                    bestTags = point.tags
                }
            }
            guard let tags = bestTags, bestDist <= Self.osmMatchRadiusM else {
                return station
            }
            let brand = tags["brand"] ?? tags["brand:fr"] ?? tags["operator"] ?? station.brand
            let osmName = tags["name"] ?? tags["name:fr"]
            let newName: String = {
                if let osmName, !osmName.isEmpty { return osmName }
                if (station.name == "Station" || station.name.isEmpty), let brand { return brand }
                return station.name
            }()
            return Station(
                id: station.id,
                name: newName,
                brand: brand,
                address: station.address,
                city: station.city,
                coordinates: station.coordinates,
                fuels: station.fuels,
                services: station.services
            )
        }
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

    /// Official French government dataset (Ministère de l'Économie):
    /// "Prix des carburants en France – Flux instantané – v2"
    /// API: OpenDataSoft Explore v2.1 — https://data.economie.gouv.fr
    private static let datasetURL =
        "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records"

    private static let pageLimit = 100
    private static let maxRecordsPerPoint = 300

    private func fetchSingle(
        point: Coordinate,
        fuelIds: [Int],
        rangeMeters: Int
    ) async throws -> [Station] {
        var whereParts: [String] = [
            "within_distance(geom, GEOM'POINT(\(point.lon) \(point.lat))', \(max(1, rangeMeters))m)"
        ]

        if !fuelIds.isEmpty {
            let priceFields = FuelMapping.all
                .filter { fuelIds.contains($0.id) }
                .map { "\($0.priceField) IS NOT NULL" }
            if !priceFields.isEmpty {
                whereParts.append("(" + priceFields.joined(separator: " OR ") + ")")
            }
        }

        let whereClause = whereParts.joined(separator: " AND ")

        var stationsById: [Int: Station] = [:]
        var offset = 0
        while offset < Self.maxRecordsPerPoint {
            var components = URLComponents(string: Self.datasetURL)!
            components.queryItems = [
                URLQueryItem(name: "where", value: whereClause),
                URLQueryItem(name: "limit", value: String(Self.pageLimit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]

            guard let url = components.url else {
                AppLog.stations.error("fetchSingle URL invalide")
                throw StationError.badResponse
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            AppLog.stations.debug("fetchSingle GET \(url.absoluteString, privacy: .public)")

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
                  httpResponse.statusCode == 200 else {
                let bodyPreview = String(data: data.prefix(200), encoding: .utf8) ?? ""
                AppLog.stations.error("fetchSingle bad status \(status) bodyPrefix=\(bodyPreview, privacy: .public)")
                throw StationError.badResponse
            }

            let envelope: OdsRecordsResponse
            do {
                envelope = try JSONDecoder().decode(OdsRecordsResponse.self, from: data)
            } catch {
                AppLog.stations.error("fetchSingle JSON decode failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }

            let records = envelope.results ?? []
            for record in records {
                if let station = record.toStation() {
                    stationsById[station.id] = station
                }
            }

            if records.count < Self.pageLimit { break }
            offset += Self.pageLimit
        }

        return Array(stationsById.values)
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
