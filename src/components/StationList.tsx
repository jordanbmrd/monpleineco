import type { Station } from "@/lib/prixCarburants";

type StationItem = Station & {
    bestPrice: number;
    bestFuelLabel: string;
    distanceToRoute: number;
    rank: number;
};

type StationListProps = {
    stations: StationItem[];
    onCenterMap?: (lat: number, lon: number) => void;
};

const formatPrice = (value: number) =>
    new Intl.NumberFormat("fr-FR", {
        minimumFractionDigits: 3,
        maximumFractionDigits: 3,
    }).format(value);

const formatDistance = (meters: number) => {
    if (meters >= 1000) {
        return `${(meters / 1000).toFixed(1)} km`;
    }
    return `${Math.round(meters)} m`;
};

const StationList = ({ stations, onCenterMap }: StationListProps) => {
    if (!stations.length) {
        return (
            <div className="rounded-2xl border border-slate-200 bg-white p-6 text-sm text-slate-500">
                Aucune station trouvée sur l&apos;itinéraire.
            </div>
        );
    }

    const openInGoogleMaps = (lat: number, lon: number) => {
        window.open(
            `https://www.google.com/maps/search/?api=1&query=${lat},${lon}`,
            "_blank",
        );
    };

    return (
        <div className="space-y-3">
            {stations.map((station) => (
                <div
                    key={station.id}
                    className={`rounded-2xl border p-4 shadow-sm transition ${station.rank <= 10
                        ? "border-amber-200 bg-amber-50/60"
                        : "border-slate-200 bg-white"
                        } hover:border-slate-300`}
                >
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-semibold text-slate-900 break-word">
                                #{station.rank} · {station.name}
                            </p>
                            <p className="text-xs text-slate-500">
                                {station.brand ?? "Station indépendante"}
                            </p>
                            <p className="text-xs text-slate-500 break-word">
                                {station.address ?? "Adresse inconnue"},{" "}
                                {station.city ?? "Ville inconnue"}
                            </p>
                        </div>
                        <div className="flex items-start justify-between gap-3 sm:flex-col sm:text-right sm:justify-start">
                            {station.rank <= 10 && (
                                <span className="inline-flex items-center rounded-full bg-amber-200 px-2 py-0.5 text-[10px] font-semibold text-amber-900 shrink-0">
                                    Top 10
                                </span>
                            )}
                            <div className="text-right sm:text-right">
                                <p className="text-sm font-semibold text-slate-900">
                                    {formatPrice(station.bestPrice)} €/L
                                </p>
                                <p className="text-xs text-slate-500">{station.bestFuelLabel}</p>
                                <p className="text-xs text-slate-400">
                                    {formatDistance(station.distanceToRoute)}
                                </p>
                            </div>
                        </div>
                    </div>
                    <div className="mt-3 flex flex-col gap-2 sm:flex-row">
                        {onCenterMap && (
                            <button
                                onClick={() => onCenterMap(station.coordinates.lat, station.coordinates.lon)}
                                className="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 active:bg-slate-100 touch-manipulation"
                            >
                                📍 Centrer sur la carte
                            </button>
                        )}
                        <button
                            onClick={() => openInGoogleMaps(station.coordinates.lat, station.coordinates.lon)}
                            className="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 active:bg-slate-100 touch-manipulation"
                        >
                            🗺️ Ouvrir dans Google Maps
                        </button>
                    </div>
                </div>
            ))}
        </div>
    );
};

export default StationList;
