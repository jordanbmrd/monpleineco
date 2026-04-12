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

const rankClass = (rank: number) => {
    if (rank === 1) return "station-card--rank-1";
    if (rank === 2) return "station-card--rank-2";
    if (rank === 3) return "station-card--rank-3";
    return "";
};

const rankBadgeClass = (rank: number) => {
    if (rank === 1) return "rank-badge rank-badge--1";
    if (rank === 2) return "rank-badge rank-badge--2";
    if (rank === 3) return "rank-badge rank-badge--3";
    return "rank-badge rank-badge--other";
};

const rankEmoji = (rank: number) => {
    if (rank === 1) return "🥇";
    if (rank === 2) return "🥈";
    if (rank === 3) return "🥉";
    return null;
};

const StationList = ({ stations, onCenterMap }: StationListProps) => {
    if (!stations.length) {
        return (
            <div className="empty-state">
                <div style={{ fontSize: 32, marginBottom: 10 }}>🔍</div>
                <p style={{ fontWeight: 600, color: "#475569", marginBottom: 4, fontSize: 14 }}>
                    Aucune station trouvée
                </p>
                <p style={{ fontSize: 13 }}>
                    Essaie d&apos;élargir ta recherche ou de changer de carburant.
                </p>
            </div>
        );
    }

    const openInGoogleMaps = (lat: number, lon: number) => {
        window.open(
            `https://www.google.com/maps/search/?api=1&query=${lat},${lon}`,
            "_blank",
        );
    };

    const cheapestPrice = stations[0]?.bestPrice ?? 0;

    return (
        <div className="space-y-3 mt-2">
            {stations.map((station) => {
                const isTop3 = station.rank <= 3;
                const savings = station.rank === 1 && stations.length > 1
                    ? null
                    : null; // Could compute vs avg here if desired
                void savings;

                return (
                    <div
                        key={station.id}
                        className={`station-card ${rankClass(station.rank)} ${station.rank <= 10 ? "station-card--top" : ""}`}
                    >
                        <div className="flex items-start justify-between gap-3">
                            <div className="flex-1 min-w-0">
                                {/* Rank + brand row */}
                                <div className="flex items-center gap-2 mb-1.5">
                                    <span className={rankBadgeClass(station.rank)}>
                                        {isTop3 ? rankEmoji(station.rank) : `#${station.rank}`}
                                    </span>
                                    <span
                                        style={{
                                            fontSize: 11,
                                            fontWeight: 600,
                                            color: "var(--text-3)",
                                            overflow: "hidden",
                                            textOverflow: "ellipsis",
                                            whiteSpace: "nowrap",
                                        }}
                                    >
                                        {station.brand ?? "Indépendant"}
                                    </span>
                                    {station.rank === 1 && (
                                        <span className="best-price-label">
                                            Moins cher
                                        </span>
                                    )}
                                </div>

                                {/* Station name */}
                                <p
                                    style={{
                                        fontSize: 14,
                                        fontWeight: 700,
                                        color: "var(--text-1)",
                                        lineHeight: 1.3,
                                        overflow: "hidden",
                                        textOverflow: "ellipsis",
                                        whiteSpace: "nowrap",
                                        marginBottom: 2,
                                    }}
                                >
                                    {station.name}
                                </p>

                                {/* Address */}
                                <p
                                    style={{
                                        fontSize: 12,
                                        color: "var(--text-3)",
                                        overflow: "hidden",
                                        textOverflow: "ellipsis",
                                        whiteSpace: "nowrap",
                                    }}
                                >
                                    {station.address ?? "Adresse inconnue"}
                                    {station.city ? `, ${station.city}` : ""}
                                </p>
                            </div>

                            {/* Price block */}
                            <div style={{ textAlign: "right", flexShrink: 0 }}>
                                <p
                                    style={{
                                        fontSize: isTop3 ? 20 : 17,
                                        fontWeight: 800,
                                        color: station.rank === 1 ? "var(--brand)" : "var(--text-1)",
                                        fontVariantNumeric: "tabular-nums",
                                        letterSpacing: "-0.5px",
                                        lineHeight: 1.1,
                                    }}
                                >
                                    {formatPrice(station.bestPrice)}
                                </p>
                                <p
                                    style={{
                                        fontSize: 11,
                                        color: "var(--text-3)",
                                        fontWeight: 500,
                                        marginTop: 2,
                                    }}
                                >
                                    €/L · {station.bestFuelLabel}
                                </p>
                                {station.distanceToRoute > 0 && (
                                    <p style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>
                                        {formatDistance(station.distanceToRoute)}
                                    </p>
                                )}
                                {station.rank > 1 && cheapestPrice > 0 && (
                                    <p
                                        style={{
                                            fontSize: 10,
                                            color: "#ef4444",
                                            fontWeight: 600,
                                            marginTop: 2,
                                        }}
                                    >
                                        +{((station.bestPrice - cheapestPrice) * 100).toFixed(1)} c
                                    </p>
                                )}
                            </div>
                        </div>

                        {/* Actions */}
                        <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
                            {onCenterMap && (
                                <button
                                    onClick={() =>
                                        onCenterMap(station.coordinates.lat, station.coordinates.lon)
                                    }
                                    className="card-action"
                                >
                                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                                        <circle cx="12" cy="10" r="3" />
                                    </svg>
                                    Carte
                                </button>
                            )}
                            <button
                                onClick={() =>
                                    openInGoogleMaps(station.coordinates.lat, station.coordinates.lon)
                                }
                                className="card-action card-action--nav"
                            >
                                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                                    <polygon points="3 11 22 2 13 21 11 13 3 11" />
                                </svg>
                                Y aller
                            </button>
                        </div>
                    </div>
                );
            })}
        </div>
    );
};

export default StationList;
