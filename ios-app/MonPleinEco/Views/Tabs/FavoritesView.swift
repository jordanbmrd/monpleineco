import SwiftUI

struct FavoritesView: View {
    private var favoritesManager = FavoritesManager.shared
    @AppStorage("defaultFuelRawValue") private var defaultFuelRawValue = FuelType.sp95E10.rawValue
    @AppStorage("tankSize") private var tankSize = 50
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
                    detourDuration: nil,
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
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.06))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.brand.opacity(0.04))
                    .frame(width: 90, height: 90)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.brand.opacity(0.35))
            }

            VStack(spacing: 8) {
                Text("Aucun favori")
                    .font(.title3.weight(.bold))

                Text("Ajoutez des stations pour suivre leurs prix.")
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
        ScrollView {
            if favoritesManager.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Actualisation…")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            LazyVStack(spacing: 12) {
                ForEach(favoritesManager.favorites) { station in
                    Button {
                        path.append(station)
                    } label: {
                        FavoriteStationCard(
                            station: station,
                            preferredFuel: preferredFuel,
                            tankSize: tankSize
                        )
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.screenHorizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Favorite Station Card

private struct FavoriteStationCard: View {
    let station: Station
    let preferredFuel: FuelType
    let tankSize: Int

    private var fuelEntry: StationFuel? {
        station.fuels.first { $0.id == preferredFuel.rawValue }
    }

    private var isUnavailable: Bool {
        guard let entry = fuelEntry else { return true }
        return !entry.available || entry.price == nil
    }

    private var dropColor: Color {
        preferredFuel.dropColor
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Fuel icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isUnavailable ? Color(.tertiarySystemFill) : dropColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isUnavailable ? Color(.tertiaryLabel) : dropColor)
                }

                // Station info
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let brand = station.brand {
                            Text(brand)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let city = station.city {
                            if station.brand != nil {
                                Circle()
                                    .fill(Color(.quaternaryLabel))
                                    .frame(width: 3, height: 3)
                            }
                            Text(city)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Price or unavailable badge
                if isUnavailable {
                    Text("Indisponible")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                } else if let price = fuelEntry?.price {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(FormattingUtils.formatPrice(price))
                                .font(.system(.title3, design: .rounded, weight: .black))
                                .foregroundStyle(.brand)
                                .monospacedDigit()
                            Text("€/L")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.secondary)
                        }

                        let total = price * Double(tankSize)
                        Text("\(String(format: "%.2f", total)) € le plein")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.quaternary)
                    .padding(.leading, 2)
            }
            .padding(16)

            // Fuel type indicator bar
            if !isUnavailable {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dropColor)
                        .frame(width: 6, height: 6)
                    Text(preferredFuel.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, -2)
            }
        }
        .background(Color.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isUnavailable ? Color.cardBorder : dropColor.opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        .shadow(color: .black.opacity(0.02), radius: 3, y: 1)
    }
}
