import Foundation
import MapKit

enum ViewState: Equatable {
    case form
    case results
}

enum SortOption: String, CaseIterable {
    case price = "Prix croissant"
    case distance = "Distance"
}

@Observable
final class SearchViewModel {
    // MARK: - Search inputs
    var searchMode: SearchMode = .around
    var fromQuery = ""
    var toQuery = ""
    var addressQuery = ""
    var selectedFuel: FuelType = .sp95E10
    var avoidTolls = true
    var swapTrigger = false

    // MARK: - UI state
    var viewState: ViewState = .form
    var isLoading = false
    var error: String?
    var selectedStation: StationWithMetrics?

    // MARK: - Results
    var stations: [StationWithMetrics] = []
    var routeResult: RouteResult?
    var startPoint: Coordinate?
    var endPoint: Coordinate?

    // MARK: - Filters
    var sortBy: SortOption = .price
    var selectedBrand: String = ""
    var availableBrands: [String] = []

    // MARK: - Recent searches
    var recentSearches: [RecentSearch] = []

    // MARK: - Location
    let locationManager = LocationManager()
    /// Coordinate used to center the map on launch (nil = fall back to Paris)
    var userCoordinate: CLLocationCoordinate2D?

    init() {
        recentSearches = SearchHistoryManager.load()
    }

    // Called once at app launch: asks for location, fills addressQuery and exposes userCoordinate.
    @MainActor
    func setupInitialLocation() async {
        guard let coord = await locationManager.locateForStartup() else { return }
        userCoordinate = coord
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let place = placemarks.first {
                // Fill with the city (or neighbourhood) name only — keeps the field concise
                let label = [place.locality ?? place.subLocality, place.postalCode]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !label.isEmpty {
                    addressQuery = label
                }
            }
        } catch {
            // Geocoding failed; coordinate is still stored for map centering
        }
    }

    // MARK: - Computed

    var filteredStations: [StationWithMetrics] {
        var filtered = stations
        if !selectedBrand.isEmpty {
            filtered = filtered.filter { ($0.station.brand ?? "Autres") == selectedBrand }
        }
        filtered.sort { a, b in
            switch sortBy {
            case .price: a.bestPrice < b.bestPrice
            case .distance: a.distanceToRoute < b.distanceToRoute
            }
        }
        return filtered.enumerated().map { index, s in
            var copy = s
            copy.rank = index + 1
            return copy
        }
    }

    var isReadyToSearch: Bool {
        switch searchMode {
        case .route:
            return !fromQuery.trimmingCharacters(in: .whitespaces).isEmpty
                && !toQuery.trimmingCharacters(in: .whitespaces).isEmpty
        case .around:
            return !addressQuery.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Actions

    func swapRouteEndpoints() {
        let temp = fromQuery
        fromQuery = toQuery
        toQuery = temp
        swapTrigger.toggle()
    }

    @MainActor
    func search() async {
        guard isReadyToSearch else { return }
        error = nil
        isLoading = true
        viewState = .results
        selectedStation = nil

        do {
            if searchMode == .route {
                try await searchRoute()
            } else {
                try await searchAround()
            }
        } catch {
            self.error = error.localizedDescription
            stations = []
        }

        isLoading = false
    }

    @MainActor
    func restoreRecentSearch(_ recent: RecentSearch) async {
        searchMode = recent.mode
        selectedFuel = recent.fuelType ?? .sp95E10
        if recent.mode == .route {
            fromQuery = recent.from ?? ""
            toQuery = recent.to ?? ""
            avoidTolls = recent.avoidTolls ?? true
        } else {
            addressQuery = recent.address ?? ""
        }
        await search()
    }

    func goBackToForm() {
        viewState = .form
        selectedStation = nil
    }

    func selectStation(_ station: StationWithMetrics) {
        if viewState == .form {
            viewState = .results
        }
        selectedStation = station
    }

    func deselectStation() {
        selectedStation = nil
    }

    @MainActor
    func geolocate() async {
        do {
            let coord = try await locationManager.locateOnce()
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let place = placemarks.first {
                let parts = [
                    place.name,
                    place.thoroughfare,
                    [place.postalCode, place.locality].compactMap { $0 }.joined(separator: " ")
                ].compactMap { $0 }.filter { !$0.isEmpty }
                addressQuery = parts.joined(separator: ", ")
            } else {
                addressQuery = "\(coord.latitude), \(coord.longitude)"
            }
        } catch {
            self.error = "Impossible de déterminer votre position."
        }
    }

    // MARK: - Private

    @MainActor
    private func searchRoute() async throws {
        let fromTrimmed = fromQuery.trimmingCharacters(in: .whitespaces)
        let toTrimmed = toQuery.trimmingCharacters(in: .whitespaces)

        async let startGeocode = geocode(fromTrimmed)
        async let endGeocode = geocode(toTrimmed)
        let (startCoord, endCoord) = try await (startGeocode, endGeocode)

        startPoint = startCoord
        endPoint = endCoord

        let route = try await RoutingService.calculateRoute(
            from: startCoord,
            to: endCoord,
            avoidTolls: avoidTolls
        )
        routeResult = route

        let targetCalls = min(40, max(12, Int(ceil(route.distance / 15000))))
        let spacing = max(6000, route.distance / Double(targetCalls))
        let sampledPoints = GeoUtils.sampleRoutePoints(
            coordinates: route.coordinates,
            spacingMeters: spacing
        )

        let rawStations = try await StationService.shared.fetchStationsAround(
            points: sampledPoints,
            fuelIds: [selectedFuel.rawValue]
        )

        let fuelIds = [selectedFuel.rawValue]
        let mapped: [StationWithMetrics] = rawStations.compactMap { station in
            enrichStation(station, fuelIds: fuelIds, polyline: route.coordinates, maxDistance: 5000)
        }
        let sorted = mapped.sorted { $0.bestPrice < $1.bestPrice }
        let enriched = rankStations(sorted)

        stations = enriched
        updateBrands(from: enriched)
        saveSearch(label: "\(fromTrimmed) → \(toTrimmed)", from: fromTrimmed, to: toTrimmed)
    }

    @MainActor
    private func searchAround() async throws {
        let trimmed = addressQuery.trimmingCharacters(in: .whitespaces)
        let point = try await geocode(trimmed)
        startPoint = point
        endPoint = nil
        routeResult = nil

        let rawStations = try await StationService.shared.fetchStationsAround(
            points: [point],
            fuelIds: [selectedFuel.rawValue]
        )

        let fuelIds = [selectedFuel.rawValue]
        let mapped: [StationWithMetrics] = rawStations.compactMap { station in
            enrichStation(station, fuelIds: fuelIds, referencePoint: point)
        }
        let sorted = mapped.sorted { $0.bestPrice < $1.bestPrice }
        let enriched = rankStations(sorted)

        stations = enriched
        updateBrands(from: enriched)
        saveSearch(label: trimmed, address: trimmed)
    }

    private func geocode(_ query: String) async throws -> Coordinate {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
            latitudinalMeters: 1_200_000,
            longitudinalMeters: 1_200_000
        )
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        guard let item = response.mapItems.first else {
            throw GeocodingError.notFound
        }
        return Coordinate(
            lat: item.placemark.coordinate.latitude,
            lon: item.placemark.coordinate.longitude
        )
    }

    private func enrichStation(
        _ station: Station,
        fuelIds: [Int],
        polyline: [Coordinate]? = nil,
        referencePoint: Coordinate? = nil,
        maxDistance: Double = .infinity
    ) -> StationWithMetrics? {
        let candidates = station.fuels.filter { fuel in
            fuelIds.contains(fuel.id) && fuel.available && fuel.price != nil
        }
        guard let best = candidates.min(by: { ($0.price ?? .infinity) < ($1.price ?? .infinity) }),
              let bestPrice = best.price else {
            return nil
        }
        let dist: Double
        if let polyline {
            dist = GeoUtils.distancePointToPolylineMeters(point: station.coordinates, polyline: polyline)
            guard dist <= maxDistance else { return nil }
        } else if let ref = referencePoint {
            dist = GeoUtils.haversineMeters(ref, station.coordinates)
        } else {
            dist = 0
        }
        return StationWithMetrics(
            station: station,
            bestPrice: bestPrice,
            bestFuelLabel: best.shortName,
            distanceToRoute: dist,
            rank: 0
        )
    }

    private func rankStations(_ sorted: [StationWithMetrics]) -> [StationWithMetrics] {
        sorted.enumerated().map { index, s in
            var copy = s
            copy.rank = index + 1
            return copy
        }
    }

    private func updateBrands(from stations: [StationWithMetrics]) {
        let brands = Set(stations.map { $0.station.brand ?? "Autres" }).sorted()
        availableBrands = brands
        selectedBrand = ""
    }

    private func saveSearch(
        label: String,
        from: String? = nil,
        to: String? = nil,
        address: String? = nil
    ) {
        let search = RecentSearch(
            mode: searchMode,
            label: label,
            from: from,
            to: to,
            address: address,
            fuelId: selectedFuel.rawValue,
            avoidTolls: searchMode == .route ? avoidTolls : nil,
            timestamp: Date()
        )
        recentSearches = SearchHistoryManager.save(search)
    }

    enum GeocodingError: LocalizedError {
        case notFound
        var errorDescription: String? { "Adresse introuvable." }
    }
}
