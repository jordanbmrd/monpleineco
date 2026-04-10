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
            <div className="empty-state">
                <div className="text-3xl mb-3">🔍</div>
                <p className="font-medium text-slate-600 mb-1">Aucune station trouvée</p>
                <p className="text-sm">Essaie d&apos;élargir ta recherche ou de changer de carburant.</p>
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
                    className={`station-card ${station.rank <= 10 ? "station-card--top" : ""}`}
                >
                    <div className="flex items-start justify-between gap-3">
                        <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                                {station.rank <= 10 && (
                                    <span className="inline-flex items-center rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-bold text-amber-700">
                                        #{station.rank}
                                    </span>
                                )}
                                {station.rank > 10 && (
                                    <span className="text-xs font-medium text-slate-400">
                                        #{station.rank}
                                    </span>
                                )}
                                <span className="text-xs font-medium text-slate-400 truncate">
                                    {station.brand ?? "Indépendant"}
                                </span>
                            </div>
                            <p className="text-sm font-semibold text-slate-900 leading-snug">
                                {station.name}
                            </p>
                            <p className="text-xs text-slate-500 mt-0.5 truncate">
                                {station.address ?? "Adresse inconnue"}, {station.city ?? ""}
                            </p>
                        </div>
                        <div className="text-right shrink-0">
                            <p className="text-lg font-bold text-slate-900 tabular-nums">
                                {formatPrice(station.bestPrice)}
                            </p>
                            <p className="text-[11px] text-slate-400 font-medium">
                                €/L · {station.bestFuelLabel}
                            </p>
                            {station.distanceToRoute > 0 && (
                                <p className="text-[11px] text-slate-400 mt-0.5">
                                    {formatDistance(station.distanceToRoute)}
                                </p>
                            )}
                        </div>
                    </div>
                    <div className="mt-3 flex gap-2">
                        {onCenterMap && (
                            <button
                                onClick={() => onCenterMap(station.coordinates.lat, station.coordinates.lon)}
                                className="card-action"
                            >
                                📍 Carte
                            </button>
                        )}
                        <button
                            onClick={() => openInGoogleMaps(station.coordinates.lat, station.coordinates.lon)}
                            className="card-action"
                        >
                            🗺️ Y aller
                        </button>
                    </div>
                </div>
            ))}
        </div>
    );
};

export default StationList;
