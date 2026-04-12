import SwiftUI

struct FavoritesView: View {
    private var favoritesManager = FavoritesManager.shared
    @AppStorage("defaultFuelRawValue") private var defaultFuelRawValue = FuelType.sp95E10.rawValue
    @State private var path = NavigationPath()

    private var preferredFuel: FuelType {
        FuelType(rawValue: defaultFuelRawValue) ?? .sp95E10
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if favoritesManager.favorites.isEmpty {
                    emptyState
                } else {
                    favoritesList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Favoris")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Station.self) { station in
                let entry = station.fuels.first { $0.id == preferredFuel.rawValue }
                let metrics = StationWithMetrics(
                    station: station,
                    bestPrice: entry?.price ?? 0,
                    bestFuelLabel: entry?.shortName ?? preferredFuel.shortName,
                    distanceToRoute: 0,
                    rank: 0
                )
                StationDetailView(station: metrics)
            }
            .task {
                await favoritesManager.refreshPrices()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "heart.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.brand.opacity(0.4))
            }

            VStack(spacing: 8) {
                Text("Aucun favori")
                    .font(.title3.weight(.bold))

                Text("Vos stations favorites apparaîtront ici.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoritesList: some View {
        List {
            if favoritesManager.isRefreshing {
                HStack {
                    Spacer()
                    ProgressView("Actualisation des prix…")
                        .font(.caption)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            ForEach(favoritesManager.favorites) { station in
                Button {
                    path.append(station)
                } label: {
                    FavoriteStationRow(station: station, preferredFuel: preferredFuel)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            favoritesManager.toggle(station)
                        }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Favorite Station Row

private struct FavoriteStationRow: View {
    let station: Station
    let preferredFuel: FuelType

    private var preferredFuelEntry: StationFuel? {
        station.fuels.first { $0.id == preferredFuel.rawValue }
    }

    private var isUnavailable: Bool {
        guard let entry = preferredFuelEntry else { return true }
        return !entry.available || entry.price == nil
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "fuelpump.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(isUnavailable ? Color.secondary : Color.brand)
                .frame(width: 44, height: 44)
                .background((isUnavailable ? Color.secondary : Color.brand).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(station.brand ?? "Indépendant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isUnavailable {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Indisponible")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(preferredFuel.shortName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            } else if let price = preferredFuelEntry?.price {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(FormattingUtils.formatPrice(price))
                        .font(.system(.callout, design: .rounded, weight: .heavy))
                        .foregroundStyle(.brand)
                        .monospacedDigit()
                    Text(preferredFuel.shortName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}
