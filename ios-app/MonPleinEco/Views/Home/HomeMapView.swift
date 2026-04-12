import SwiftUI
import MapKit

struct HomeMapView: View {
    @Bindable var vm: SearchViewModel
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )
    @State private var navigateToDetail = false
    @State private var visibleStationIndex: Int = 0
    @State private var currentSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    @State private var carouselID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                mapLayer.ignoresSafeArea()

                VStack {
                    if let route = vm.routeResult, vm.searchMode == .route {
                        routeInfoBar(route)
                            .padding(.horizontal, Theme.Spacing.screenHorizontal)
                            .padding(.top, 4)
                    }

                    Spacer()

                    if vm.isLoading && vm.filteredStations.isEmpty && !vm.isHomeSearchExpanded {
                        loadingCarouselPlaceholder
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !vm.filteredStations.isEmpty && !vm.isHomeSearchExpanded {
                        bottomCarousel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    searchOverlay
                        .padding(.horizontal, Theme.Spacing.screenHorizontal)
                        .padding(.bottom, 8)
                }
            }
            .onChange(of: vm.userCoordinate) { old, coord in
                handleUserCoordinate(old, coord)
            }
            .onChange(of: vm.filteredStations) { _, stations in
                carouselID = UUID()
                if stations.isEmpty {
                    fitMapToContent()
                } else {
                    visibleStationIndex = 0
                    zoomToStation(at: 0)
                }
            }
            .onChange(of: vm.selectedStation) { old, station in
                handleSelectedStation(old, station)
            }
            .navigationDestination(item: Binding(
                get: { vm.selectedStation },
                set: { vm.selectedStation = $0 }
            )) { station in
                StationDetailView(station: station)
            }
        }
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        SearchOverlayView(vm: vm, isExpanded: $vm.isHomeSearchExpanded)
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        let clusterResult = computeClusters()
        Map(position: $mapPosition) {
            UserAnnotation()

            if let route = vm.routeResult {
                MapPolyline(route.polyline)
                    .stroke(.brandGradient, lineWidth: 5)
            }

            if let start = vm.startPoint, vm.searchMode == .route {
                Annotation("Départ", coordinate: start.clLocation) {
                    routeMarkerBubble(systemName: "flag.fill", color: .brand)
                }
                .annotationTitles(.hidden)
            }
            if let end = vm.endPoint, vm.searchMode == .route {
                Annotation("Arrivée", coordinate: end.clLocation) {
                    routeMarkerBubble(systemName: "flag.checkered", color: .red)
                }
                .annotationTitles(.hidden)
            }

            ForEach(clusterResult.singles) { station in
                Annotation(
                    station.station.name,
                    coordinate: station.station.coordinates.clLocation,
                    anchor: .bottom
                ) {
                    PriceAnnotationView(
                        station: station,
                        isSelected: vm.selectedStation?.id == station.id
                    )
                    .onTapGesture {
                        vm.selectStation(station)
                    }
                }
                .annotationTitles(.hidden)
            }

            ForEach(clusterResult.clusters) { cluster in
                Annotation(
                    "",
                    coordinate: cluster.center,
                    anchor: .center
                ) {
                    ClusterAnnotationView(count: cluster.count)
                        .onTapGesture {
                            zoomToCluster(cluster)
                        }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { context in
            currentSpan = context.region.span
        }
        .onTapGesture { _ in
            if vm.isHomeSearchExpanded {
                withAnimation {
                    vm.isHomeSearchExpanded = false
                }
            }
        }
    }

    // MARK: - Clustering

    private struct ClusterGroup: Identifiable {
        let id = UUID()
        let center: CLLocationCoordinate2D
        let count: Int
        var stations: [StationWithMetrics]
    }

    private struct ClusterResult {
        let singles: [StationWithMetrics]
        let clusters: [ClusterGroup]
    }

    private func computeClusters() -> ClusterResult {
        let allStations = vm.filteredStations
        guard !allStations.isEmpty else {
            return ClusterResult(singles: [], clusters: [])
        }

        let top3 = allStations.filter { $0.rank <= 3 }
        let rest = allStations.filter { $0.rank > 3 }

        let threshold = currentSpan.latitudeDelta * 0.06
        guard threshold > 0.005, !rest.isEmpty else {
            return ClusterResult(singles: allStations, clusters: [])
        }

        var clustered: [[StationWithMetrics]] = []
        var used = Set<Int>()

        for (i, s) in rest.enumerated() {
            guard !used.contains(i) else { continue }
            var group = [s]
            used.insert(i)
            for (j, other) in rest.enumerated() where j > i && !used.contains(j) {
                let dLat = abs(s.station.coordinates.lat - other.station.coordinates.lat)
                let dLon = abs(s.station.coordinates.lon - other.station.coordinates.lon)
                if dLat < threshold && dLon < threshold {
                    group.append(other)
                    used.insert(j)
                }
            }
            clustered.append(group)
        }

        var singles = top3
        var clusterGroups: [ClusterGroup] = []

        for group in clustered {
            if group.count == 1 {
                singles.append(group[0])
            } else {
                let avgLat = group.map(\.station.coordinates.lat).reduce(0, +) / Double(group.count)
                let avgLon = group.map(\.station.coordinates.lon).reduce(0, +) / Double(group.count)
                clusterGroups.append(ClusterGroup(
                    center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    count: group.count,
                    stations: group
                ))
            }
        }

        return ClusterResult(singles: singles, clusters: clusterGroups)
    }

    private func routeMarkerBubble(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .shadow(color: color.opacity(0.3), radius: 6, y: 3)
    }

    private func zoomToCluster(_ cluster: ClusterGroup) {
        let lats = cluster.stations.map(\.station.coordinates.lat)
        let lons = cluster.stations.map(\.station.coordinates.lon)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (lats.max()! - lats.min()!) * 2),
            longitudeDelta: max(0.01, (lons.max()! - lons.min()!) * 2)
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    // MARK: - Bottom Carousel (paged, 1 card visible at a time)

    private var bottomCarousel: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - Theme.Spacing.screenHorizontal * 2
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(vm.filteredStations.enumerated()), id: \.element.id) { index, station in
                        StationCarouselCard(station: station) {
                            vm.selectStation(station)
                        }
                        .frame(width: cardWidth)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { visibleStationIndex },
                set: { newVal in
                    if let newVal { visibleStationIndex = newVal }
                }
            ))
            .id(carouselID)
        }
        .frame(height: 150)
        .padding(.bottom, 10)
        .onChange(of: visibleStationIndex) { _, newIndex in
            zoomToStation(at: newIndex)
        }
    }

    private var loadingCarouselPlaceholder: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.brand)
            Text("Recherche des stations…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.Spacing.screenHorizontal)
        .padding(.bottom, 10)
    }

    private func zoomToStation(at index: Int) {
        let stations = vm.filteredStations
        guard index >= 0 && index < stations.count else { return }
        let coord = stations[index].station.coordinates.clLocation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            mapPosition = .camera(MapCamera(centerCoordinate: coord, distance: 5000))
        }
    }

    // MARK: - Route Info

    private func routeInfoBar(_ route: RouteResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.brand)

                Text("\(vm.fromQuery) → \(vm.toQuery)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 8) {
                Text(FormattingUtils.formatDistance(route.distance))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)

                Text(FormattingUtils.formatDuration(route.duration))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.brand)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Map Fitting

    private func handleUserCoordinate(_ old: CLLocationCoordinate2D?, _ coord: CLLocationCoordinate2D?) {
        guard let coord, old == nil else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            ))
        }
    }

    private func handleSelectedStation(_ old: StationWithMetrics?, _ station: StationWithMetrics?) {
        if let station {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                mapPosition = .camera(MapCamera(
                    centerCoordinate: station.station.coordinates.clLocation,
                    distance: 3000
                ))
            }
        } else if old != nil {
            fitMapToContent()
        }
    }

    private func fitMapToContent() {
        var coords: [CLLocationCoordinate2D] = []
        if let route = vm.routeResult {
            coords.append(contentsOf: route.coordinates.map(\.clLocation))
        }
        for station in vm.filteredStations {
            coords.append(station.station.coordinates.clLocation)
        }
        if let start = vm.startPoint { coords.append(start.clLocation) }
        if let end = vm.endPoint { coords.append(end.clLocation) }
        guard !coords.isEmpty else { return }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (lats.max()! - lats.min()!) * 1.3),
            longitudeDelta: max(0.02, (lons.max()! - lons.min()!) * 1.3)
        )
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}
