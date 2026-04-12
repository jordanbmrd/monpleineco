import SwiftUI
import MapKit

struct SearchOverlayView: View {
    @Bindable var vm: SearchViewModel
    @Binding var isExpanded: Bool

    @State private var completer = AddressCompleter()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.searchBar, style: .continuous))
        .shadow(
            color: Theme.Shadow.searchBar.color,
            radius: Theme.Shadow.searchBar.radius,
            y: Theme.Shadow.searchBar.y
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    // MARK: - Collapsed Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

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
                        triggerSearch()
                    }
            } else {
                Button {
                    withAnimation { isExpanded = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        fieldFocused = true
                    }
                } label: {
                    Text(vm.addressQuery.isEmpty ? "Trouver une station..." : vm.addressQuery)
                        .font(.subheadline)
                        .foregroundStyle(vm.addressQuery.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Button {
                    Task { await vm.geolocate() }
                } label: {
                    if vm.locationManager.isLocating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.brand)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Color.brand.opacity(0.1))
                .clipShape(Circle())

                Button {
                    withAnimation {
                        isExpanded = false
                        fieldFocused = false
                        completer.clear()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)
            } else {
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
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal, 16)

            if !completer.suggestions.isEmpty {
                suggestionsView
            }

            fuelChips

            Button {
                triggerSearch()
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
        VStack(spacing: 0) {
            ForEach(completer.suggestions, id: \.self) { suggestion in
                Button {
                    let label = [suggestion.title, suggestion.subtitle]
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    vm.addressQuery = label
                    completer.clear()
                    fieldFocused = false
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

                if suggestion != completer.suggestions.last {
                    Divider().padding(.leading, 46)
                }
            }
        }
    }

    private func triggerSearch() {
        vm.searchMode = .around
        fieldFocused = false
        withAnimation { isExpanded = false }
        completer.clear()
        Task { await vm.search() }
    }
}
