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
    static let myLocationLabel = "Ma position"

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
    var isHomeSearchExpanded = false

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

    private var fuelObserver: NSObjectProtocol?

    var isLocationAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
    }

    init() {
        recentSearches = SearchHistoryManager.load()
        syncFuelFromDefaults()
        if locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways {
            fromQuery = Self.myLocationLabel
        }

        fuelObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFuelFromDefaults()
        }
    }

    deinit {
        if let obs = fuelObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private func syncFuelFromDefaults() {
        let savedRaw = UserDefaults.standard.integer(forKey: "defaultFuelRawValue")
        guard savedRaw != 0, let fuel = FuelType(rawValue: savedRaw), fuel != selectedFuel else { return }
        selectedFuel = fuel
        // Cached results were computed with the previous fuel — drop them.
        snapshots.removeAll()
        Task { @MainActor in
            await refreshAfterFuelChange()
        }
    }

    @MainActor
    private func refreshAfterFuelChange() async {
        guard viewState == .results else { return }
        switch searchMode {
        case .around:
            if let point = startPoint {
                let coord = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
                await searchAroundCoordinate(coord)
            } else if isReadyToSearch {
                await search()
            }
        case .route:
            if isReadyToSearch {
                await search()
            }
        }
    }

    // Called once at app launch: asks for location, centres the map immediately,
    // then geocodes + searches in the background so stations appear faster.
    @MainActor
    func setupInitialLocation() async {
        guard let coord = await locationManager.locateForStartup() else { return }
        // Centre the map right away — no need to wait for geocoding/search
        userCoordinate = coord

        // Start the API search using raw coordinates immediately (no geocode needed)
        let point = Coordinate(lat: coord.latitude, lon: coord.longitude)
        searchMode = .around
        isLoading = true
        viewState = .results
        startPoint = point
        endPoint = nil
        routeResult = nil

        // Fire geocode and station fetch concurrently
        async let geocodeTask: String? = {
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            if let place = placemarks?.first {
                let label = [place.locality ?? place.subLocality, place.postalCode]
                    .compactMap { $0 }
                    .joined(separator: " ")
                return label.isEmpty ? nil : label
            }
            return nil
        }()

        async let stationsTask: [Station] = {
            (try? await StationService.shared.fetchStationsAround(
                points: [point],
                fuelIds: [self.selectedFuel.rawValue]
            )) ?? []
        }()

        let (label, rawStations) = await (geocodeTask, stationsTask)

        // Fill address bar with geocoded name (cosmetic)
        if let label { addressQuery = label }

        // Enrich results
        let fuelIds = [selectedFuel.rawValue]
        let mapped: [StationWithMetrics] = rawStations.compactMap { station in
            enrichStation(station, fuelIds: fuelIds, referencePoint: point)
        }
        let sorted = mapped.sorted(by: priceSort)
        let enriched = rankStations(sorted)

        stations = enriched
        updateBrands(from: enriched)
        if let label { saveSearch(label: label, address: label) }

        isLoading = false
    }

    // MARK: - Computed

    var filteredStations: [StationWithMetrics] {
        var filtered = stations
        if !selectedBrand.isEmpty {
            filtered = filtered.filter { ($0.station.brand ?? "Autres") == selectedBrand }
        }
        filtered.sort { a, b in
            switch sortBy {
            case .price: priceSort(a, b)
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

    // MARK: - Mode switching

    private struct ResultsSnapshot {
        var stations: [StationWithMetrics]
        var routeResult: RouteResult?
        var startPoint: Coordinate?
        var endPoint: Coordinate?
        var viewState: ViewState
        var addressQuery: String
        var fromQuery: String
        var toQuery: String
        var availableBrands: [String]
        var selectedBrand: String
        var sortBy: SortOption
        var avoidTolls: Bool
    }

    private var snapshots: [SearchMode: ResultsSnapshot] = [:]

    private func captureSnapshot() -> ResultsSnapshot {
        ResultsSnapshot(
            stations: stations,
            routeResult: routeResult,
            startPoint: startPoint,
            endPoint: endPoint,
            viewState: viewState,
            addressQuery: addressQuery,
            fromQuery: fromQuery,
            toQuery: toQuery,
            availableBrands: availableBrands,
            selectedBrand: selectedBrand,
            sortBy: sortBy,
            avoidTolls: avoidTolls
        )
    }

    private func restore(_ snap: ResultsSnapshot) {
        stations = snap.stations
        routeResult = snap.routeResult
        startPoint = snap.startPoint
        endPoint = snap.endPoint
        viewState = snap.viewState
        addressQuery = snap.addressQuery
        fromQuery = snap.fromQuery
        toQuery = snap.toQuery
        availableBrands = snap.availableBrands
        selectedBrand = snap.selectedBrand
        sortBy = snap.sortBy
        avoidTolls = snap.avoidTolls
    }

    func switchMode(to mode: SearchMode) {
        guard mode != searchMode else { return }
        snapshots[searchMode] = captureSnapshot()
        searchMode = mode
        error = nil
        selectedStation = nil

        if let snap = snapshots[mode] {
            restore(snap)
        } else {
            stations = []
            routeResult = nil
            startPoint = nil
            endPoint = nil
            viewState = .form
            availableBrands = []
            selectedBrand = ""
            if mode == .route && fromQuery.trimmingCharacters(in: .whitespaces).isEmpty && isLocationAuthorized {
                fromQuery = Self.myLocationLabel
            }
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
        guard isReadyToSearch else {
            AppLog.search.debug("search aborted: not ready (mode=\(String(describing: self.searchMode)) address='\(self.addressQuery)' from='\(self.fromQuery)' to='\(self.toQuery)')")
            return
        }
        error = nil
        isLoading = true
        viewState = .results
        selectedStation = nil

        AppLog.search.debug("search start mode=\(String(describing: self.searchMode)) fuel=\(self.selectedFuel.label) rawValue=\(self.selectedFuel.rawValue)")

        do {
            if searchMode == .route {
                try await searchRoute()
            } else {
                try await searchAround()
            }
            AppLog.search.debug("search done stations.count=\(self.stations.count) filtered=\(self.filteredStations.count)")
        } catch {
            AppLog.search.error("search failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
            stations = []
        }

        isLoading = false
    }

    @MainActor
    func searchAroundCoordinate(_ coord: CLLocationCoordinate2D) async {
        let point = Coordinate(lat: coord.latitude, lon: coord.longitude)
        searchMode = .around
        error = nil
        selectedStation = nil
        isLoading = true
        viewState = .results
        startPoint = point
        endPoint = nil
        routeResult = nil

        async let geocodeTask: String? = {
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            if let place = placemarks?.first {
                let label = [place.locality ?? place.subLocality, place.postalCode]
                    .compactMap { $0 }
                    .joined(separator: " ")
                return label.isEmpty ? nil : label
            }
            return nil
        }()

        async let stationsTask: [Station] = {
            (try? await StationService.shared.fetchStationsAround(
                points: [point],
                fuelIds: [self.selectedFuel.rawValue]
            )) ?? []
        }()

        let (label, rawStations) = await (geocodeTask, stationsTask)

        if let label { addressQuery = label }

        let fuelIds = [selectedFuel.rawValue]
        let mapped: [StationWithMetrics] = rawStations.compactMap { station in
            enrichStation(station, fuelIds: fuelIds, referencePoint: point)
        }
        let sorted = mapped.sorted(by: priceSort)
        let enriched = rankStations(sorted)

        stations = enriched
        updateBrands(from: enriched)
        if let label { saveSearch(label: label, address: label) }

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

    @MainActor
    func geolocateFromQuery() async {
        do {
            let coord = try await locationManager.locateOnce()
            userCoordinate = coord
            fromQuery = Self.myLocationLabel
        } catch {
            self.error = "Impossible de déterminer votre position."
        }
    }

    // MARK: - Private

    @MainActor
    private func searchRoute() async throws {
        let fromTrimmed = fromQuery.trimmingCharacters(in: .whitespaces)
        let toTrimmed = toQuery.trimmingCharacters(in: .whitespaces)

        let startCoord: Coordinate
        if fromTrimmed == Self.myLocationLabel {
            let coord: CLLocationCoordinate2D
            if let existing = userCoordinate {
                coord = existing
            } else {
                coord = try await locationManager.locateOnce()
                userCoordinate = coord
            }
            startCoord = Coordinate(lat: coord.latitude, lon: coord.longitude)
        } else {
            startCoord = try await geocode(fromTrimmed)
        }
        let endCoord = try await geocode(toTrimmed)

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
        AppLog.search.debug("searchRoute API rawStations=\(rawStations.count) samplePoints=\(sampledPoints.count)")

        let fuelIds = [selectedFuel.rawValue]
        let avgSpeed = route.duration > 0 ? route.distance / route.duration : 0
        let mapped: [StationWithMetrics] = rawStations.compactMap { station in
            enrichStation(
                station,
                fuelIds: fuelIds,
                polyline: route.coordinates,
                maxDistance: 5000,
                routeAverageSpeed: avgSpeed
            )
        }
        if rawStations.isEmpty {
            AppLog.search.warning("searchRoute: 0 stations renvoyées par l’API sur le trajet")
        } else if mapped.isEmpty {
            logSampleStationFuels(rawStations.first, label: "searchRoute enrich a tout filtré")
        }
        let sorted = mapped.sorted(by: priceSort)
        let enriched = rankStations(sorted)

        stations = enriched
        updateBrands(from: enriched)
        saveSearch(label: "\(fromTrimmed) → \(toTrimmed)", from: fromTrimmed, to: toTrimmed)
    }

    @MainActor
    private func searchAround() async throws {
        let trimmed = addressQuery.trimmingCharacters(in: .whitespaces)
        AppLog.search.debug("searchAround geocode query='\(trimmed, privacy: .public)'")
        let point = try await geocode(trimmed)
        AppLog.search.debug("searchAround coord lat=\(point.lat) lon=\(point.lon)")
        startPoint = point
        endPoint = nil
        routeResult = nil

        let rawStations = try await StationService.shared.fetchStationsAround(
            points: [point],
            fuelIds: [selectedFuel.rawValue]
        )
        AppLog.search.debug("searchAround API rawStations=\(rawStations.count)")

        let fuelIds = [selectedFuel.rawValue]
        let mapped: [StationWithMetrics] = rawStations.compactMap { station in
            enrichStation(station, fuelIds: fuelIds, referencePoint: point)
        }
        if rawStations.isEmpty {
            AppLog.search.warning("searchAround: 0 stations dans le rayon API (point=\(point.lat),\(point.lon))")
        } else if mapped.isEmpty {
            logSampleStationFuels(rawStations.first, label: "searchAround enrich a tout filtré (prix/carburant ?)")
        }
        let sorted = mapped.sorted(by: priceSort)
        let enriched = rankStations(sorted)

        stations = enriched
        updateBrands(from: enriched)
        saveSearch(label: trimmed, address: trimmed)
    }

    private var geocodeCache: [String: Coordinate] = [:]

    private func geocode(_ query: String) async throws -> Coordinate {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespaces)
        if let cached = geocodeCache[normalized] {
            return cached
        }

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
            AppLog.search.error("geocode aucun résultat pour query='\(query, privacy: .public)'")
            throw GeocodingError.notFound
        }
        let coord = Coordinate(
            lat: item.placemark.coordinate.latitude,
            lon: item.placemark.coordinate.longitude
        )
        geocodeCache[normalized] = coord
        return coord
    }

    private func enrichStation(
        _ station: Station,
        fuelIds: [Int],
        polyline: [Coordinate]? = nil,
        referencePoint: Coordinate? = nil,
        maxDistance: Double = .infinity,
        routeAverageSpeed: Double = 0
    ) -> StationWithMetrics? {
        let candidates = station.fuels.filter { fuel in
            fuelIds.contains(fuel.id) && fuel.available && fuel.price != nil
        }
        guard let best = candidates.min(by: { ($0.price ?? .infinity) < ($1.price ?? .infinity) }),
              let bestPrice = best.price else {
            return nil
        }
        let dist: Double
        var detour: TimeInterval? = nil
        if let polyline {
            dist = GeoUtils.distancePointToPolylineMeters(point: station.coordinates, polyline: polyline)
            guard dist <= maxDistance else { return nil }
            if routeAverageSpeed > 0 {
                // Approximation: detour = leaving the route and coming back (~2× perpendicular distance),
                // driven at the route's average speed.
                detour = (2.0 * dist) / routeAverageSpeed
            }
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
            detourDuration: detour,
            rank: 0
        )
    }

    /// Tie-break price equality with distance (around mode) or detour duration (route mode)
    /// so the top ranks reflect the closest / least-detour station among equal-priced ones.
    private func priceSort(_ a: StationWithMetrics, _ b: StationWithMetrics) -> Bool {
        if a.bestPrice != b.bestPrice { return a.bestPrice < b.bestPrice }
        switch searchMode {
        case .route:
            return (a.detourDuration ?? .infinity) < (b.detourDuration ?? .infinity)
        case .around:
            return a.distanceToRoute < b.distanceToRoute
        }
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

    private func logSampleStationFuels(_ station: Station?, label: String) {
        guard let station else { return }
        let summary = station.fuels.map { f in
            "\(f.id):\(f.shortName) avail=\(f.available) price=\(f.price.map { String($0) } ?? "nil")"
        }.joined(separator: "; ")
        AppLog.search.warning("\(label) stationId=\(station.id) fuels=[\(summary, privacy: .public)]")
    }
}
