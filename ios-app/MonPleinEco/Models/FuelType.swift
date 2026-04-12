import Foundation
import SwiftUI

enum FuelType: Int, CaseIterable, Codable, Identifiable {
    case gazole = 1
    case sp95 = 2
    case e85 = 3
    case gplc = 4
    case sp95E10 = 5
    case sp98 = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .gazole: "Gazole"
        case .sp95: "SP95"
        case .e85: "E85"
        case .gplc: "GPLc"
        case .sp95E10: "SP95-E10"
        case .sp98: "SP98"
        }
    }

    var shortName: String {
        switch self {
        case .gazole: "Gazole"
        case .sp95: "SP95"
        case .e85: "E85"
        case .gplc: "GPLc"
        case .sp95E10: "E10"
        case .sp98: "SP98"
        }
    }

    static let displayOrder: [FuelType] = [.sp95E10, .sp98, .gazole, .sp95, .e85, .gplc]

    static let detailSortOrder: [FuelType] = [.gazole, .sp95E10, .sp95, .sp98, .e85, .gplc]

    var dropColor: Color {
        switch self {
        case .gazole: Color.orange
        case .sp95: Color(red: 0.5, green: 0.85, blue: 0.3)    // vert clair
        case .sp95E10: Color.cyan                                 // bleu ciel/cyan
        case .sp98: Color(red: 0.1, green: 0.55, blue: 0.2)     // vert foncé
        case .gplc: Color(red: 0.1, green: 0.2, blue: 0.7)      // bleu foncé
        case .e85: Color(red: 0.4, green: 0.7, blue: 0.95)      // bleu clair
        }
    }
}
