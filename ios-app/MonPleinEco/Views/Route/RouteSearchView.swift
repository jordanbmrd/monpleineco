import SwiftUI
import MapKit

struct RouteSearchView: View {
    @Bindable var vm: SearchViewModel
    @State private var showOptions = false
    @State private var showResults = false
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack {
                if showResults && !vm.filteredStations.isEmpty {
                    routeMapView
                        .ignoresSafeArea()
                } else {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    if showResults {
                        routeResultsOverlay
                    } else {
                        routeForm
                    }
                }
            }
            .navigationTitle("Itinéraire")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if showResults {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                showResults = false
                                vm.goBackToForm()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption.weight(.bold))
                                Text("Recherche")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(.brand)
                        }
                    }
                }
            }
            .onChange(of: vm.viewState) { _, newState in
                if newState == .results && vm.searchMode == .route {
                    withAnimation(.spring(response: 0.35)) {
                        showResults = true
                    }
                    fitRouteMap()
                }
            }
            .navigationDestination(item: Binding(
                get: { vm.selectedStation },
                set: { vm.selectedStation = $0 }
            )) { station in
                StationDetailView(station: station)
            }
        }
    }

    // MARK: - Route Form

    private var routeForm: some View {
        ScrollView {
            VStack(spacing: 20) {
                routeFields
                fuelSection
                recentSearchesSection
                searchButton
            }
            .padding(.horizontal, Theme.Spacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var routeFields: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                AddressSearchField(placeholder: "Départ", text: $vm.fromQuery)

                HStack {
                    Divider()
                        .frame(height: 20)
                        .padding(.leading, 20)
                    Spacer()
                    Button {
                        vm.swapRouteEndpoints()
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.brand)
                            .frame(width: 32, height: 32)
                            .background(Color.brand.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: vm.swapTrigger)
                    Spacer()
                    Divider()
                        .frame(height: 20)
                        .padding(.trailing, 20)
                }

                AddressSearchField(placeholder: "Arrivée", text: $vm.toQuery)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showOptions.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Options")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.quaternary)
                            .rotationEffect(.degrees(showOptions ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)

                if showOptions {
                    HStack(spacing: 8) {
                        ToggleChip(label: "Sans péages", isSelected: vm.avoidTolls) {
                            vm.avoidTolls = true
                        }
                        ToggleChip(label: "Avec péages", isSelected: !vm.avoidTolls) {
                            vm.avoidTolls = false
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .formSection()
        }
    }

    private var fuelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Carburant")
                .sectionLabel()
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FuelType.displayOrder) { fuel in
                        FuelChipView(
                            fuel: fuel,
                            isSelected: vm.selectedFuel == fuel
                        ) {
                            vm.selectedFuel = fuel
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        let filtered = vm.recentSearches.filter { $0.mode == .route }
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recherches récentes")
                    .sectionLabel()
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filtered) { recent in
                            Button {
                                Task { await vm.restoreRecentSearch(recent) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.swap")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.brand)
                                    Text(recent.label)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let fuel = recent.fuelType {
                                        Text(fuel.shortName)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.brand)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.brand.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.chipH)
                                .padding(.vertical, Theme.Spacing.chipV)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var searchButton: some View {
        VStack(spacing: 12) {
            if let error = vm.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.suggestion, style: .continuous))
            }

            Button {
                vm.searchMode = .route
                Task { await vm.search() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(vm.isLoading ? "Recherche en cours..." : "Rechercher")
                }
            }
            .buttonStyle(GradientButtonStyle(isEnabled: isRouteReady))
            .disabled(!isRouteReady || vm.isLoading)
        }
    }

    private var isRouteReady: Bool {
        !vm.fromQuery.trimmingCharacters(in: .whitespaces).isEmpty
        && !vm.toQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Route Results Map

    @ViewBuilder
    private var routeMapView: some View {
        Map(position: $mapPosition) {
            UserAnnotation()

            if let route = vm.routeResult {
                MapPolyline(route.polyline)
                    .stroke(.brandGradient, lineWidth: 5)
            }

            if let start = vm.startPoint {
                Annotation("Départ", coordinate: start.clLocation) {
                    markerBubble(systemName: "flag.fill", color: .brand)
                }
                .annotationTitles(.hidden)
            }
            if let end = vm.endPoint {
                Annotation("Arrivée", coordinate: end.clLocation) {
                    markerBubble(systemName: "flag.checkered", color: .red)
                }
                .annotationTitles(.hidden)
            }

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

    private var routeResultsOverlay: some View {
        VStack(spacing: 0) {
            if let route = vm.routeResult {
                routeInfoCard(route)
                    .padding(.horizontal, Theme.Spacing.screenHorizontal)
                    .padding(.top, 8)
            }

            Spacer()

            if !vm.filteredStations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Stations sur le trajet")
                            .font(.headline.weight(.bold))
                        Spacer()
                        FilterBarView(
                            sortBy: $vm.sortBy,
                            selectedBrand: $vm.selectedBrand,
                            availableBrands: vm.availableBrands
                        )
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func routeInfoCard(_ route: RouteResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.brand)
                .frame(width: 44, height: 44)
                .background(Color.brand.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.fromQuery) → \(vm.toQuery)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(FormattingUtils.formatDistance(route.distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(FormattingUtils.formatDuration(route.duration))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.brand)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(
            color: Theme.Shadow.floatingCard.color,
            radius: Theme.Shadow.floatingCard.radius,
            y: Theme.Shadow.floatingCard.y
        )
    }

    private func markerBubble(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .shadow(color: color.opacity(0.3), radius: 6, y: 3)
    }

    private func fitRouteMap() {
        var coords: [CLLocationCoordinate2D] = []
        if let route = vm.routeResult {
            coords.append(contentsOf: route.coordinates.map { $0.clLocation })
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
