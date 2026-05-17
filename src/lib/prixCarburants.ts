import { haversineMeters, type LatLng } from "./geo";

// Official French government dataset (Ministère de l'Économie):
// "Prix des carburants en France – Flux instantané – v2"
// API: OpenDataSoft Explore v2.1 — https://data.economie.gouv.fr
const DATASET_URL =
    "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records";

const PAGE_LIMIT = 100;
const MAX_RECORDS_PER_POINT = 300;

export type StationFuel = {
    id: number;
    name: string;
    shortName: string;
    available: boolean;
    price: number | null;
    updatedAt: string | null;
};

export type Station = {
    id: number;
    name: string;
    brand: string | null;
    address: string | null;
    city: string | null;
    coordinates: LatLng;
    fuels: StationFuel[];
};

// Mapping between internal fuel ids and the flat columns of the v2 dataset.
const FUEL_DEFINITIONS: Array<{
    id: number;
    name: string;
    shortName: string;
    priceField: string;
    updateField: string;
    availableLabel: string;
}> = [
    { id: 1, name: "Gazole", shortName: "Gazole", priceField: "gazole_prix", updateField: "gazole_maj", availableLabel: "Gazole" },
    { id: 2, name: "SP95", shortName: "SP95", priceField: "sp95_prix", updateField: "sp95_maj", availableLabel: "SP95" },
    { id: 3, name: "E85", shortName: "E85", priceField: "e85_prix", updateField: "e85_maj", availableLabel: "E85" },
    { id: 4, name: "GPLc", shortName: "GPLc", priceField: "gplc_prix", updateField: "gplc_maj", availableLabel: "GPLc" },
    { id: 5, name: "SP95-E10", shortName: "E10", priceField: "e10_prix", updateField: "e10_maj", availableLabel: "E10" },
    { id: 6, name: "SP98", shortName: "SP98", priceField: "sp98_prix", updateField: "sp98_maj", availableLabel: "SP98" },
];

type ApiRecord = Record<string, unknown>;

const toNumber = (value: unknown): number | null => {
    if (value === null || value === undefined || value === "") return null;
    const n = typeof value === "number" ? value : Number(value);
    return Number.isFinite(n) ? n : null;
};

const toString = (value: unknown): string | null => {
    if (value === null || value === undefined) return null;
    const s = String(value).trim();
    return s.length ? s : null;
};

const extractCoordinates = (record: ApiRecord): LatLng | null => {
    const geo = (record.geom ?? record.geo_point_2d ?? record.geo_point) as
        | { lat?: number; lon?: number; coordinates?: number[] }
        | null
        | undefined;
    if (geo && typeof geo === "object") {
        if (typeof geo.lat === "number" && typeof geo.lon === "number") {
            return { lat: geo.lat, lon: geo.lon };
        }
        if (Array.isArray(geo.coordinates) && geo.coordinates.length >= 2) {
            const [lon, lat] = geo.coordinates;
            if (typeof lat === "number" && typeof lon === "number") {
                return { lat, lon };
            }
        }
    }
    const lat = toNumber(record.latitude);
    const lon = toNumber(record.longitude);
    if (lat !== null && lon !== null) {
        return { lat, lon };
    }
    return null;
};

const extractAvailableSet = (value: unknown): Set<string> => {
    const set = new Set<string>();
    if (Array.isArray(value)) {
        for (const item of value) {
            const s = toString(item);
            if (s) set.add(s.toLowerCase());
        }
    } else if (typeof value === "string") {
        for (const item of value.split(/[,;|]/)) {
            const s = item.trim().toLowerCase();
            if (s) set.add(s);
        }
    }
    return set;
};

const mapRecord = (record: ApiRecord): Station | null => {
    const coordinates = extractCoordinates(record);
    if (!coordinates) return null;

    const rawId = record.id ?? record.station_id;
    const numericId = typeof rawId === "number" ? rawId : Number(String(rawId ?? "").replace(/\D/g, ""));
    if (!Number.isFinite(numericId) || numericId <= 0) {
        return null;
    }

    const availableSet = extractAvailableSet(record.carburants_disponibles);

    const fuels: StationFuel[] = FUEL_DEFINITIONS.map((def) => {
        const price = toNumber(record[def.priceField]);
        const updatedAt = toString(record[def.updateField]);
        // A fuel is "available" if it's listed in carburants_disponibles
        // or if we have a current price for it.
        const available =
            availableSet.has(def.availableLabel.toLowerCase()) || price !== null;
        return {
            id: def.id,
            name: def.name,
            shortName: def.shortName,
            available,
            price,
            updatedAt,
        };
    });

    const address = toString(record.adresse);
    const city = toString(record.ville);
    const postal = toString(record.cp);
    const cityLine = postal && city ? `${postal} ${city}` : city ?? postal;

    return {
        id: numericId,
        name: toString(record.name) ?? city ?? "Station",
        brand: toString(record.marque) ?? toString(record.brand) ?? toString(record.enseigne),
        address,
        city: cityLine,
        coordinates,
        fuels,
    };
};

const fetchAroundPoint = async (
    point: LatLng,
    fuelIds: number[],
    rangeMeters: number,
): Promise<Station[]> => {
    const lon = point.lon;
    const lat = point.lat;
    // ODS v2.1 spatial filter: within_distance(geom, GEOM'POINT(lon lat)', Xm)
    const whereParts: string[] = [
        `within_distance(geom, GEOM'POINT(${lon} ${lat})', ${Math.max(1, Math.round(rangeMeters))}m)`,
    ];

    if (fuelIds.length) {
        const priceFields = FUEL_DEFINITIONS.filter((def) => fuelIds.includes(def.id)).map(
            (def) => `${def.priceField} IS NOT NULL`,
        );
        if (priceFields.length) {
            whereParts.push(`(${priceFields.join(" OR ")})`);
        }
    }

    const where = whereParts.join(" AND ");
    const results: Station[] = [];

    for (let offset = 0; offset < MAX_RECORDS_PER_POINT; offset += PAGE_LIMIT) {
        const url = new URL(DATASET_URL);
        url.searchParams.set("where", where);
        url.searchParams.set("limit", String(PAGE_LIMIT));
        url.searchParams.set("offset", String(offset));

        const response = await fetch(url.toString(), {
            headers: { Accept: "application/json" },
        });

        if (!response.ok) {
            const text = await response.text().catch(() => "");
            throw new Error(`${response.status} ${text.slice(0, 120)}`);
        }

        const data = (await response.json()) as {
            total_count?: number;
            results?: ApiRecord[];
        };

        const records = Array.isArray(data.results) ? data.results : [];
        for (const record of records) {
            const station = mapRecord(record);
            if (station) results.push(station);
        }

        if (records.length < PAGE_LIMIT) break;
    }

    return results;
};

export const fetchStationsAround = async (
    points: LatLng[],
    fuelIds: number[],
    rangeMeters: number,
) => {
    const limitedPoints = points.slice(0, 40);
    const stationsById = new Map<number, Station>();
    const errors: string[] = [];

    await Promise.all(
        limitedPoints.map(async (point) => {
            try {
                const stations = await fetchAroundPoint(point, fuelIds, rangeMeters);
                for (const station of stations) {
                    stationsById.set(station.id, station);
                }
            } catch (err) {
                errors.push(
                    `Point ${point.lat},${point.lon}: ${err instanceof Error ? err.message : "Erreur inconnue"}`,
                );
            }
        }),
    );

    if (errors.length > 0 && stationsById.size === 0) {
        console.error("Erreurs lors de la récupération des stations:", errors);
        throw new Error(
            `Impossible de récupérer les stations. Erreurs: ${errors.slice(0, 3).join("; ")}`,
        );
    }

    const stations = Array.from(stationsById.values());
    await enrichWithOsm(stations);
    return stations;
};

// MARK: - OSM enrichment (brand / name / operator)
//
// The official government dataset doesn't carry brand or station name.
// We complement it with OpenStreetMap data via the Overpass API:
// `amenity=fuel` nodes/ways typically carry `brand`, `name`, `operator`
// tags. Matching is done by nearest-neighbour within a tolerance, since
// the government coordinates are rounded.

const OVERPASS_URL = "https://overpass-api.de/api/interpreter";
const OSM_MATCH_RADIUS_M = 250;
const OSM_BBOX_PADDING_DEG = 0.005;

type OverpassElement = {
    type: string;
    lat?: number;
    lon?: number;
    center?: { lat?: number; lon?: number };
    tags?: Record<string, string>;
};

const enrichWithOsm = async (stations: Station[]): Promise<void> => {
    if (!stations.length) return;

    const lats = stations.map((s) => s.coordinates.lat);
    const lons = stations.map((s) => s.coordinates.lon);
    const south = Math.min(...lats) - OSM_BBOX_PADDING_DEG;
    const north = Math.max(...lats) + OSM_BBOX_PADDING_DEG;
    const west = Math.min(...lons) - OSM_BBOX_PADDING_DEG;
    const east = Math.max(...lons) + OSM_BBOX_PADDING_DEG;

    const bbox = `${south},${west},${north},${east}`;
    const query =
        `[out:json][timeout:25];` +
        `(node["amenity"="fuel"](${bbox});way["amenity"="fuel"](${bbox}););` +
        `out center tags;`;

    try {
        const response = await fetch(OVERPASS_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "MonPleinEco/1.0 (+https://monpleineco.fr)",
                Accept: "application/json",
            },
            body: "data=" + encodeURIComponent(query),
        });
        if (!response.ok) return;

        const data = (await response.json()) as { elements?: OverpassElement[] };
        const nodes = (data.elements ?? [])
            .map((el) => {
                const lat = el.lat ?? el.center?.lat;
                const lon = el.lon ?? el.center?.lon;
                if (typeof lat !== "number" || typeof lon !== "number") return null;
                return { lat, lon, tags: el.tags ?? {} };
            })
            .filter((n): n is { lat: number; lon: number; tags: Record<string, string> } => n !== null);

        if (!nodes.length) return;

        for (const station of stations) {
            let bestDist = Infinity;
            let bestTags: Record<string, string> | null = null;
            for (const node of nodes) {
                const dist = haversineMeters(station.coordinates, { lat: node.lat, lon: node.lon });
                if (dist < bestDist) {
                    bestDist = dist;
                    bestTags = node.tags;
                }
            }
            if (!bestTags || bestDist > OSM_MATCH_RADIUS_M) continue;

            const brand =
                bestTags.brand ?? bestTags["brand:fr"] ?? bestTags.operator ?? null;
            const name = bestTags.name ?? bestTags["name:fr"] ?? null;

            if (brand && !station.brand) {
                (station as { brand: string | null }).brand = brand;
            }
            if (name) {
                (station as { name: string }).name = name;
            } else if (brand && (station.name === "Station" || !station.name)) {
                (station as { name: string }).name = brand;
            }
        }
    } catch (err) {
        console.warn("OSM enrichment failed:", err);
    }
};
