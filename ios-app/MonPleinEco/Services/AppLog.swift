import Foundation
import OSLog

/// Logs de debug (Console Xcode : filtrer par « MonPleinEco » ou la catégorie).
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "fr.monpleineco.ios"

    static let search = Logger(subsystem: subsystem, category: "Search")
    static let stations = Logger(subsystem: subsystem, category: "Stations")
}
