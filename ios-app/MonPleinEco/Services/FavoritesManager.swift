import Foundation

@Observable
final class FavoritesManager {
    static let shared = FavoritesManager()

    private static let key = "monpleineco_favorites"

    private(set) var favorites: [Station] = []
    var isRefreshing = false

    private init() {
        favorites = Self.load()
    }

    func isFavorite(_ stationId: Int) -> Bool {
        favorites.contains { $0.id == stationId }
    }

    func toggle(_ station: Station) {
        if let index = favorites.firstIndex(where: { $0.id == station.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(station, at: 0)
        }
        save()
    }

    @MainActor
    func refreshPrices() async {
        guard !favorites.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var updated: [Station] = []
        for fav in favorites {
            do {
                let fresh = try await StationService.shared.fetchStationsAround(
                    points: [fav.coordinates],
                    fuelIds: [],
                    rangeMeters: 500
                )
                if let match = fresh.first(where: { $0.id == fav.id }) {
                    updated.append(match)
                } else {
                    updated.append(fav)
                }
            } catch {
                updated.append(fav)
            }
        }
        favorites = updated
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static func load() -> [Station] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Station].self, from: data)) ?? []
    }
}
