import SwiftUI
import MapKit

struct SearchOverlayView: View {
    @Bindable var vm: SearchViewModel
    @Binding var isExpanded: Bool

    @State private var completer = AddressCompleter()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded && vm.searchMode == .around && !completer.suggestions.isEmpty {
                suggestionsView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                Divider().padding(.horizontal, 16)
            }

            modePicker
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            if vm.searchMode == .around {
                aroundSearchBar
            } else {
                routeSearchBar
            }

            if isExpanded || vm.searchMode == .route {
                Divider().padding(.horizontal, 16)
                bottomExpandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.searchBar, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: Theme.Radius.searchBar, style: .continuous)
                    .fill(.thinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.searchBar, style: .continuous))
        .shadow(
            color: Theme.Shadow.searchBar.color,
            radius: Theme.Shadow.searchBar.radius,
            y: Theme.Shadow.searchBar.y
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.searchMode)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: completer.suggestions.isEmpty)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 6) {
            modeButton(label: "Station", mode: .around, icon: "fuelpump.fill")
            modeButton(label: "Trajet", mode: .route, icon: "road.lanes")
        }
        .padding(3)
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func modeButton(label: String, mode: SearchMode, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                vm.switchMode(to: mode)
                if mode == .around {
                    isExpanded = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(vm.searchMode == mode ? Color(.systemBackground) : .clear)
            .foregroundStyle(vm.searchMode == mode ? .brand : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(
                color: vm.searchMode == mode ? .black.opacity(0.06) : .clear,
                radius: 2, y: 1
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: vm.searchMode)
    }

    // MARK: - Around Search Bar

    private var aroundSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            ZStack {
                if !isExpanded {
                    Text(vm.addressQuery.isEmpty ? "Trouver une station..." : vm.addressQuery)
                        .font(.subheadline)
                        .foregroundStyle(vm.addressQuery.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isExpanded {
                    TextField("Ville ou adresse...", text: $vm.addressQuery)
                        .font(.subheadline)
                        .focused($fieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .onChange(of: vm.addressQuery) { _, newValue in
                            completer.search(newValue)
                        }
                        .onSubmit {
                            triggerAroundSearch()
                        }
                        .onAppear { fieldFocused = true }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isExpanded else { return }
                withAnimation { isExpanded = true }
            }

            if isExpanded {
                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(0.68)
                        .frame(width: 22, height: 22)
                }

                Button {
                    Task {
                        await vm.geolocate()
                        triggerAroundSearch()
                    }
                } label: {
                    ZStack {
                        if vm.locationManager.isLocating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.brand)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(Color.brand.opacity(0.1))
                    .clipShape(Circle())
                }

                Button {
                    if !vm.addressQuery.isEmpty {
                        vm.addressQuery = ""
                        completer.clear()
                    } else {
                        withAnimation {
                            isExpanded = false
                            fieldFocused = false
                            completer.clear()
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)
            } else {
                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(0.68)
                        .frame(width: 22, height: 22)
                }
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.brand)
                    .frame(width: 36, height: 36)
                    .background(Color.brand.opacity(0.1))
                    .clipShape(Circle())
                    .onTapGesture {
                        withAnimation { isExpanded = true }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isExpanded else { return }
            withAnimation { isExpanded = true }
        }
    }

    // MARK: - Route Search Bar

    private var routeSearchBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.brand)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1.5, height: 24)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }

                VStack(spacing: 6) {
                    AddressSearchField(placeholder: "Départ", text: $vm.fromQuery)
                    AddressSearchField(placeholder: "Arrivée", text: $vm.toQuery)
                }

                Button {
                    vm.swapRouteEndpoints()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.brand)
                        .frame(width: 30, height: 30)
                        .background(Color.brand.opacity(0.1))
                        .clipShape(Circle())
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: vm.swapTrigger)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            HStack(spacing: 8) {
                ToggleChip(label: "Sans péages", isSelected: vm.avoidTolls) {
                    vm.avoidTolls = true
                }
                ToggleChip(label: "Avec péages", isSelected: !vm.avoidTolls) {
                    vm.avoidTolls = false
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Bottom Expanded Content

    private var bottomExpandedContent: some View {
        VStack(spacing: 12) {
            fuelChips

            Button {
                if vm.searchMode == .route {
                    triggerRouteSearch()
                } else {
                    triggerAroundSearch()
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(vm.isLoading ? "Recherche..." : "Rechercher")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!vm.isReadyToSearch || vm.isLoading)
            .opacity(vm.isReadyToSearch ? 1 : 0.5)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 12)
    }

    // MARK: - Fuel Chips

    private var fuelChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Carburant")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)

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
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsView: some View {
        let displayedSuggestions = Array(completer.suggestions.prefix(Theme.AddressSearch.maxSuggestions))
        return VStack(spacing: 0) {
            ForEach(displayedSuggestions, id: \.self) { suggestion in
                Button {
                    let label = [suggestion.title, suggestion.subtitle]
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    vm.addressQuery = label
                    completer.clear()
                    fieldFocused = false
                    triggerAroundSearch()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.body)
                            .foregroundStyle(.brand)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if suggestion != displayedSuggestions.last {
                    Divider().padding(.leading, 46)
                }
            }
        }
    }

    // MARK: - Actions

    private func triggerAroundSearch() {
        vm.searchMode = .around
        fieldFocused = false
        withAnimation { isExpanded = false }
        completer.clear()
        Task { await vm.search() }
    }

    private func triggerRouteSearch() {
        vm.searchMode = .route
        fieldFocused = false
        withAnimation { isExpanded = false }
        Task { await vm.search() }
    }
}
