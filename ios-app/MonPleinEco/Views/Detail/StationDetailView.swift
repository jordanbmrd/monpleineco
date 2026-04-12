import SwiftUI
import MapKit

struct StationDetailView: View {
    let station: StationWithMetrics

    @State private var lookAroundScene: MKLookAroundScene?

    private var sortedFuels: [StationFuel] {
        let order = FuelType.detailSortOrder.map(\.rawValue)
        return station.station.fuels.sorted { a, b in
            let aAvail = a.available && a.price != nil
            let bAvail = b.available && b.price != nil
            if aAvail != bAvail { return aAvail }
            let aIdx = order.firstIndex(of: a.id) ?? 99
            let bIdx = order.firstIndex(of: b.id) ?? 99
            return aIdx < bIdx
        }
    }

    private var cheapestFuelId: Int? {
        sortedFuels
            .filter { $0.available && $0.price != nil }
            .min(by: { ($0.price ?? .infinity) < ($1.price ?? .infinity) })
            .map(\.id)
    }

    private var availableCount: Int {
        sortedFuels.filter { $0.available && $0.price != nil }.count
    }

    private var lastUpdated: String? {
        let dates = station.station.fuels
            .compactMap(\.updatedAt)
            .sorted()
        guard let latest = dates.last else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr-FR")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: latest) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "fr-FR")
            display.dateStyle = .long
            display.timeStyle = .short
            return display.string(from: date)
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: latest) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "fr-FR")
            display.dateStyle = .long
            display.timeStyle = .short
            return display.string(from: date)
        }

        return latest
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 20) {
                    if let lookAroundScene {
                        LookAroundPreview(initialScene: lookAroundScene)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    }

                    navigateButton

                    infoRow

                    fuelsSection
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(station.station.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            let request = MKLookAroundSceneRequest(
                coordinate: station.station.coordinates.clLocation
            )
            lookAroundScene = try? await request.scene
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let brand = station.station.brand {
                        Text(brand.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(1)
                    }
                    Text(station.station.name)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                }
                Spacer()
                if station.rank <= 3 {
                    Text("#\(station.rank)")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.2), in: Circle())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(FormattingUtils.formatPrice(station.bestPrice))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text("€/L")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(station.bestFuelLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                let total = station.bestPrice * 50
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.2f", total)) €")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("pour 50 litres")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.screenHorizontal)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [.brand, Color(red: 15/255, green: 130/255, blue: 100/255), .brandTeal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Info Row

    private var infoRow: some View {
        VStack(spacing: 10) {
            if station.station.address != nil || station.station.city != nil {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.brand)
                        .frame(width: 28)
                    Text(addressLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }

            if station.distanceToRoute > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.brand)
                        .frame(width: 28)
                    Text(FormattingUtils.formatDistance(station.distanceToRoute))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }

            if let updated = lastUpdated {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.brand)
                        .frame(width: 28)
                    Text("Mis à jour : \(updated)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Navigate Button

    private var navigateButton: some View {
        Button {
            openNavigation()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Ouvrir dans Plans")
            }
        }
        .buttonStyle(GradientButtonStyle())
    }

    // MARK: - Fuels Section

    private var fuelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Carburants disponibles")
                    .sectionLabel()
                if availableCount > 0 {
                    Text("\(availableCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.brand)
                }
            }

            if sortedFuels.isEmpty {
                Text("Aucune information de carburant disponible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedFuels) { fuel in
                        FuelRowView(
                            fuel: fuel,
                            isBest: fuel.id == cheapestFuelId && fuel.available && fuel.price != nil
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var addressLine: String {
        [station.station.address, station.station.city]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var shareText: String {
        var parts: [String] = []
        if let brand = station.station.brand { parts.append(brand) }
        parts.append(station.station.name)
        parts.append("\(FormattingUtils.formatPrice(station.bestPrice)) €/L (\(station.bestFuelLabel))")
        let addr = [station.station.address, station.station.city].compactMap { $0 }.joined(separator: ", ")
        if !addr.isEmpty { parts.append(addr) }
        return parts.joined(separator: " · ")
    }

    private func openNavigation() {
        let coord = station.station.coordinates
        let url = URL(string: "http://maps.apple.com/?daddr=\(coord.lat),\(coord.lon)&dirflg=d")!
        UIApplication.shared.open(url)
    }
}
