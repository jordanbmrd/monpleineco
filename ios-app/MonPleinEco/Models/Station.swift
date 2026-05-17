import Foundation
import CoreLocation

struct Coordinate: Codable, Hashable {
    let lat: Double
    let lon: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct StationFuel: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String
    let available: Bool
    let price: Double?
    let updatedAt: String?

    var fuelType: FuelType? {
        FuelType(rawValue: id)
    }
}

struct Station: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let brand: String?
    let address: String?
    let city: String?
    let coordinates: Coordinate
    let fuels: [StationFuel]
    let services: [String]?
}

struct StationWithMetrics: Identifiable, Hashable {
    let station: Station
    let bestPrice: Double
    let bestFuelLabel: String
    let distanceToRoute: Double
    /// Estimated extra time (in seconds) to detour off the current route to reach this station.
    /// `nil` when not in route mode.
    let detourDuration: TimeInterval?
    var rank: Int

    var id: Int { station.id }
}

// MARK: - Fuel column mapping for the v2 dataset

struct FuelMapping {
    let id: Int
    let name: String
    let shortName: String
    let priceField: String
    let updateField: String
    let availableLabel: String

    static let all: [FuelMapping] = [
        .init(id: 1, name: "Gazole",   shortName: "Gazole", priceField: "gazole_prix", updateField: "gazole_maj", availableLabel: "Gazole"),
        .init(id: 2, name: "SP95",     shortName: "SP95",   priceField: "sp95_prix",   updateField: "sp95_maj",   availableLabel: "SP95"),
        .init(id: 3, name: "E85",      shortName: "E85",    priceField: "e85_prix",    updateField: "e85_maj",    availableLabel: "E85"),
        .init(id: 4, name: "GPLc",     shortName: "GPLc",   priceField: "gplc_prix",   updateField: "gplc_maj",   availableLabel: "GPLc"),
        .init(id: 5, name: "SP95-E10", shortName: "E10",    priceField: "e10_prix",    updateField: "e10_maj",    availableLabel: "E10"),
        .init(id: 6, name: "SP98",     shortName: "SP98",   priceField: "sp98_prix",   updateField: "sp98_maj",   availableLabel: "SP98"),
    ]
}

// MARK: - OpenDataSoft v2.1 response

struct OdsRecordsResponse: Decodable {
    let total_count: Int?
    let results: [OdsRecord]?
}

/// One record from the "prix-des-carburants-en-france-flux-instantane-v2" dataset.
/// Fields are decoded leniently because the dataset uses flattened per-fuel columns
/// and a geo point of varying shapes.
struct OdsRecord: Decodable {
    let id: FlexibleInt?
    let adresse: String?
    let ville: String?
    let cp: String?
    let marque: String?
    let brand: String?
    let enseigne: String?
    let geom: Geom?
    let carburants_disponibles: StringArray?
    let services_service: StringArray?

    let gazole_prix: Double?; let gazole_maj: String?
    let sp95_prix: Double?;   let sp95_maj: String?
    let sp98_prix: Double?;   let sp98_maj: String?
    let e10_prix: Double?;    let e10_maj: String?
    let e85_prix: Double?;    let e85_maj: String?
    let gplc_prix: Double?;   let gplc_maj: String?

    private func price(for field: String) -> Double? {
        switch field {
        case "gazole_prix": return gazole_prix
        case "sp95_prix":   return sp95_prix
        case "sp98_prix":   return sp98_prix
        case "e10_prix":    return e10_prix
        case "e85_prix":    return e85_prix
        case "gplc_prix":   return gplc_prix
        default: return nil
        }
    }

    private func update(for field: String) -> String? {
        switch field {
        case "gazole_maj": return gazole_maj
        case "sp95_maj":   return sp95_maj
        case "sp98_maj":   return sp98_maj
        case "e10_maj":    return e10_maj
        case "e85_maj":    return e85_maj
        case "gplc_maj":   return gplc_maj
        default: return nil
        }
    }

    func toStation() -> Station? {
        guard let coords = geom?.coordinate else {
            return nil
        }

        guard let numericId = id?.value, numericId > 0 else { return nil }

        let availableSet: Set<String> = Set(
            (carburants_disponibles?.values ?? []).map { $0.lowercased() }
        )

        let fuels: [StationFuel] = FuelMapping.all.map { def in
            let price = self.price(for: def.priceField)
            let updatedAt = self.update(for: def.updateField)
            let available = availableSet.contains(def.availableLabel.lowercased()) || price != nil
            return StationFuel(
                id: def.id,
                name: def.name,
                shortName: def.shortName,
                available: available,
                price: price,
                updatedAt: updatedAt
            )
        }

        let cityLine: String? = {
            if let cp = cp?.trimmingCharacters(in: .whitespaces), !cp.isEmpty,
               let v = ville?.trimmingCharacters(in: .whitespaces), !v.isEmpty {
                return "\(cp) \(v)"
            }
            return ville ?? cp
        }()

        let svc = services_service?.values ?? []

        return Station(
            id: numericId,
            name: ville ?? "Station",
            brand: marque ?? brand ?? enseigne,
            address: adresse,
            city: cityLine,
            coordinates: coords,
            fuels: fuels,
            services: svc.isEmpty ? nil : svc
        )
    }
}

// MARK: - Overpass / OSM response

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]?
}

struct OverpassElement: Decodable {
    let type: String?
    let lat: Double?
    let lon: Double?
    let center: Center?
    let tags: [String: String]?

    struct Center: Decodable {
        let lat: Double?
        let lon: Double?
    }
}

/// Decodes a value that may arrive as Int, Double, or numeric String.
struct FlexibleInt: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self) { value = Int(d); return }
        if let s = try? c.decode(String.self), let i = Int(s.filter { $0.isNumber }) {
            value = i; return
        }
        throw DecodingError.typeMismatch(
            Int.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Expected Int-like value")
        )
    }
}

/// OpenDataSoft returns geo points as either `{ "lat": .., "lon": .. }`
/// or as GeoJSON `{ "type": "Point", "coordinates": [lon, lat] }`.
struct Geom: Decodable {
    let lat: Double?
    let lon: Double?
    let coordinates: [Double]?

    var coordinate: Coordinate? {
        if let lat, let lon { return Coordinate(lat: lat, lon: lon) }
        if let c = coordinates, c.count >= 2 {
            return Coordinate(lat: c[1], lon: c[0])
        }
        return nil
    }
}

/// Tolerates the field being either a JSON array of strings or a single string with separators.
struct StringArray: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String].self) {
            values = arr
        } else if let str = try? container.decode(String.self) {
            values = str
                .split(whereSeparator: { ",;|".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            values = []
        }
    }
}
