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
    @State private var searchExpanded = false
    @State private var navigateToDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                mapLayer.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchOverlay
                        .padding(.horizontal, Theme.Spacing.screenHorizontal)
                        .padding(.top, 8)

                    Spacer()

                    if !vm.filteredStations.isEmpty && !searchExpanded {
                        bottomCarousel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .onChange(of: vm.userCoordinate) { old, coord in
                handleUserCoordinate(old, coord)
            }
            .onChange(of: vm.filteredStations) { _, _ in
                fitMapToContent()
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
        SearchOverlayView(vm: vm, isExpanded: $searchExpanded)
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $mapPosition) {
            UserAnnotation()

            ForEach(vm.filteredStations) { station in
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
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
    }

    // MARK: - Bottom Carousel

    private var bottomCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stations à proximité")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(vm.filteredStations.count) résultats")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.filteredStations) { station in
                        StationCarouselCard(station: station) {
                            vm.selectStation(station)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
            }
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.3)
            )
        )
    }

    // MARK: - Map Fitting

    private func handleUserCoordinate(_ old: CLLocationCoordinate2D?, _ coord: CLLocationCoordinate2D?) {
        guard let coord, vm.viewState == .form else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
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
        for station in vm.filteredStations {
            coords.append(station.station.coordinates.clLocation)
        }
        if let start = vm.startPoint { coords.append(start.clLocation) }
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
