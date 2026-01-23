import type { LatLng } from "./geo";

type ApiStation = {
    id: number;
    name?: string;
    Brand?: { name?: string };
    Address?: { street_line?: string; city_line?: string };
    Coordinates?: { latitude?: number; longitude?: number };
    Fuels?: Array<{
        id: number;
        name?: string;
        shortName?: string;
        available?: boolean;
        Price?: { value?: number };
    }>;
};

export type StationFuel = {
    id: number;
    name: string;
    shortName: string;
    available: boolean;
    price: number | null;
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

const mapStation = (station: ApiStation): Station | null => {
    if (!station.Coordinates) {
        return null;
    }
    const fuels =
        station.Fuels?.map((fuel) => ({
            id: fuel.id,
            name: fuel.name ?? "Carburant",
            shortName: fuel.shortName ?? "—",
            available: Boolean(fuel.available),
            price: typeof fuel.Price?.value === "number" ? fuel.Price.value : null,
        })) ?? [];

    return {
        id: station.id,
        name: station.name ?? "Station",
        brand: station.Brand?.name ?? null,
        address: station.Address?.street_line ?? null,
        city: station.Address?.city_line ?? null,
        coordinates: {
            lat: station.Coordinates.latitude ?? 0,
            lon: station.Coordinates.longitude ?? 0,
        },
        fuels,
    };
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
                const url = new URL(
                    `https://api.prix-carburants.2aaz.fr/stations/around/${point.lat},${point.lon}`,
                );
                if (fuelIds.length) {
                    url.searchParams.set("fuels", fuelIds.join(","));
                }
                url.searchParams.set("responseFields", "Fuels,Price");

                const response = await fetch(url.toString(), {
                    headers: {
                        Range: `m=0-${rangeMeters}`,
                    },
                });

                if (!response.ok) {
                    const errorText = await response.text().catch(() => "");
                    errors.push(`Point ${point.lat},${point.lon}: ${response.status} ${errorText}`);
                    return;
                }

                const data = (await response.json()) as ApiStation[];
                if (!Array.isArray(data)) {
                    errors.push(`Point ${point.lat},${point.lon}: Réponse invalide`);
                    return;
                }

                data.forEach((station) => {
                    const mapped = mapStation(station);
                    if (mapped) {
                        stationsById.set(mapped.id, mapped);
                    }
                });
            } catch (err) {
                errors.push(`Point ${point.lat},${point.lon}: ${err instanceof Error ? err.message : "Erreur inconnue"}`);
            }
        }),
    );

    if (errors.length > 0 && stationsById.size === 0) {
        console.error("Erreurs lors de la récupération des stations:", errors);
        throw new Error(`Impossible de récupérer les stations. Erreurs: ${errors.slice(0, 3).join("; ")}`);
    }

    return Array.from(stationsById.values());
};
