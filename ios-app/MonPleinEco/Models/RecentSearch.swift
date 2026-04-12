import Foundation

enum SearchMode: String, Codable {
    case around
    case route
}

struct RecentSearch: Codable, Identifiable {
    let mode: SearchMode
    let label: String
    let from: String?
    let to: String?
    let address: String?
    let fuelId: Int
    let avoidTolls: Bool?
    let timestamp: Date

    var id: Date { timestamp }

    var fuelType: FuelType? {
        FuelType(rawValue: fuelId)
    }
}
