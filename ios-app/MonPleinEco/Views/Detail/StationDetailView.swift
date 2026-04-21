import SwiftUI
import MapKit

struct StationDetailView: View {
    let station: StationWithMetrics

    @AppStorage("tankSize") private var tankSize = 50
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var appeared = false
    @State private var showNavigationPicker = false

    private var favoritesManager: FavoritesManager { FavoritesManager.shared }

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
            let rel = RelativeDateTimeFormatter()
            rel.locale = Locale(identifier: "fr-FR")
            rel.unitsStyle = .short
            return rel.localizedString(for: date, relativeTo: Date())
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: latest) {
            let rel = RelativeDateTimeFormatter()
            rel.locale = Locale(identifier: "fr-FR")
            rel.unitsStyle = .short
            return rel.localizedString(for: date, relativeTo: Date())
        }

        return latest
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroCard
                    .padding(.horizontal, Theme.Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 16) {
                    if let lookAroundScene {
                        LookAroundPreview(initialScene: lookAroundScene)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    actionButtons
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    infoCards
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    fuelsSection
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    if !stationServices.isEmpty {
                        servicesSection
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                    }

                    shareButton
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(station.station.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        favoritesManager.toggle(station.station)
                    }
                } label: {
                    Image(systemName: favoritesManager.isFavorite(station.station.id) ? "heart.fill" : "heart")
                        .symbolEffect(.bounce, value: favoritesManager.isFavorite(station.station.id))
                        .foregroundStyle(favoritesManager.isFavorite(station.station.id) ? .red : .primary)
                }
            }
        }
        .task {
            let request = MKLookAroundSceneRequest(
                coordinate: station.station.coordinates.clLocation
            )
            lookAroundScene = try? await request.scene
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 0) {
            // Top: brand + rank
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if let brand = station.station.brand {
                        Text(brand.uppercased())
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.5)
                    }
                    Text(station.station.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Spacer()
                if (1...3).contains(station.rank) {
                    rankBadge
                }
            }
            .padding(.bottom, 20)

            // Price section
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.bestFuelLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(FormattingUtils.formatPrice(station.bestPrice))
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("€/L")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Full tank estimate
                VStack(alignment: .trailing, spacing: 6) {
                    let total = station.bestPrice * Double(tankSize)
                    Text("\(String(format: "%.2f", total)) €")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Plein \(tankSize) L")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Update timestamp
            if let updated = lastUpdated {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Mis à jour \(updated)")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 12)
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 16/255, green: 140/255, blue: 70/255), location: 0),
                            .init(color: Color(red: 12/255, green: 118/255, blue: 90/255), location: 0.5),
                            .init(color: .brandTeal, location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.brand.opacity(0.35), radius: 20, y: 10)
        }
    }

    private var rankBadge: some View {
        HStack(spacing: 3) {
            Text(station.rank == 1 ? "1er" : "\(station.rank)e")
                .font(.system(.caption, design: .rounded, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        Button {
            showNavigationPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Y aller")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.brand.opacity(0.25), radius: 12, y: 6)
        }
        .confirmationDialog("Ouvrir dans…", isPresented: $showNavigationPicker, titleVisibility: .visible) {
            Button("Apple Plans") { openAppleMaps() }
            if isGoogleMapsInstalled {
                Button("Google Maps") { openGoogleMaps() }
            }
            if isWazeInstalled {
                Button("Waze") { openWaze() }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - Info Cards

    private var infoCards: some View {
        VStack(spacing: 10) {
            if station.station.address != nil || station.station.city != nil {
                infoCard(icon: "mappin.circle.fill", title: "Adresse", value: addressLine)
            }

            if station.distanceToRoute > 0 {
                infoCard(icon: "location.fill", title: "Distance", value: FormattingUtils.formatDistance(station.distanceToRoute))
            }
        }
    }

    private func infoCard(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.brand)
                .frame(width: 36, height: 36)
                .background(Color.brand.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Fuels Section

    private var fuelsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Carburants")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("\(availableCount)/\(sortedFuels.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brand.opacity(0.1), in: Capsule())
            }

            if sortedFuels.isEmpty {
                Text("Aucune information disponible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedFuels.enumerated()), id: \.element.id) { index, fuel in
                        FuelRowView(fuel: fuel)
                        if index < sortedFuels.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .background(Color.elevatedCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Services Section

    private var stationServices: [String] {
        station.station.services ?? []
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Services")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(stationServices.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brand.opacity(0.1), in: Capsule())
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 0),
                    GridItem(.flexible(), spacing: 0)
                ],
                spacing: 0
            ) {
                ForEach(Array(stationServices.enumerated()), id: \.offset) { index, service in
                    serviceRow(service, index: index)
                }
            }
            .background(Color.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
        }
    }

    private func serviceRow(_ service: String, index: Int) -> some View {
        let isLeftColumn = index % 2 == 0
        let hasRightPartner = index + 1 < stationServices.count
        let lastRowStart = (stationServices.count - 1) - ((stationServices.count - 1) % 2)
        let isLastRow = index >= lastRowStart

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: StationDetailView.icon(forService: service))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.brand)
            }

            Text(service)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            if isLeftColumn && hasRightPartner {
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(width: 1)
                    .padding(.vertical, 6)
            }
        }
        .overlay(alignment: .bottom) {
            if !isLastRow {
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(height: 1)
            }
        }
    }

    static func icon(forService service: String) -> String {
        let key = service
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "fr"))
            .lowercased()

        if key.contains("gonflage") { return "gauge.medium" }
        if key.contains("lavage") { return "sparkles" }
        if key.contains("laverie") { return "washer.fill" }
        if key.contains("toilette") { return "toilet.fill" }
        if key.contains("restauration") { return "fork.knife" }
        if key.contains("bar") { return "wineglass.fill" }
        if key.contains("boutique") { return "bag.fill" }
        if key.contains("alimentaire") { return "cart.fill" }
        if key.contains("additif") || key.contains("additive") { return "drop.fill" }
        if key.contains("colis") { return "shippingbox.fill" }
        if key.contains("dab") || key.contains("distributeur automatique de billets") || key.contains("billets") {
            return "eurosign.circle.fill"
        }
        if key.contains("automate") || key.contains("cb ") || key.contains("24/24") || key.contains("carte bancaire") {
            return "creditcard.fill"
        }
        if key.contains("poids lourds") || key.contains("piste pl") { return "truck.box.fill" }
        if key.contains("fioul") { return "flame" }
        if key.contains("gaz") { return "flame.fill" }
        if key.contains("reparation") || key.contains("entretien") { return "wrench.and.screwdriver.fill" }
        if key.contains("wifi") { return "wifi" }
        if key.contains("douche") { return "shower.fill" }
        if key.contains("piste") { return "road.lanes" }
        if key.contains("gnv") || key.contains("gpl") { return "bolt.fill" }
        if key.contains("electrique") || key.contains("borne") || key.contains("recharge") { return "bolt.car.fill" }
        if key.contains("aire") && key.contains("jeux") { return "figure.play" }
        if key.contains("parking") { return "parkingsign" }
        return "checkmark.seal.fill"
    }

    // MARK: - Share

    private var shareButton: some View {
        ShareLink(item: shareText) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                Text("Partager cette station")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.brand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.brand.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var stationPhone: String? { nil }

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

    private var isGoogleMapsInstalled: Bool {
        URL(string: "comgooglemaps://").map { UIApplication.shared.canOpenURL($0) } ?? false
    }

    private var isWazeInstalled: Bool {
        URL(string: "waze://").map { UIApplication.shared.canOpenURL($0) } ?? false
    }

    private func openAppleMaps() {
        let coord = station.station.coordinates
        let url = URL(string: "http://maps.apple.com/?daddr=\(coord.lat),\(coord.lon)&dirflg=d")!
        UIApplication.shared.open(url)
    }

    private func openGoogleMaps() {
        let coord = station.station.coordinates
        let url = URL(string: "comgooglemaps://?daddr=\(coord.lat),\(coord.lon)&directionsmode=driving")!
        UIApplication.shared.open(url)
    }

    private func openWaze() {
        let coord = station.station.coordinates
        let url = URL(string: "waze://?ll=\(coord.lat),\(coord.lon)&navigate=yes")!
        UIApplication.shared.open(url)
    }
}
