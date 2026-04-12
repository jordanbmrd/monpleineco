import Foundation

enum SearchHistoryManager {
    private static let key = "monpleineco_recent_searches"
    private static let maxRecent = 3

    static func load() -> [RecentSearch] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentSearch].self, from: data)) ?? []
    }

    @discardableResult
    static func save(_ search: RecentSearch) -> [RecentSearch] {
        var existing = load()
        existing.removeAll { $0.label == search.label }
        existing.insert(search, at: 0)
        let trimmed = Array(existing.prefix(maxRecent))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return trimmed
    }
}
