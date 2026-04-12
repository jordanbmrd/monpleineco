import type { Station, StationFuel } from "@/lib/prixCarburants";

type StationDetailProps = {
    station: Station & { bestPrice: number; bestFuelLabel: string; distanceToRoute: number; rank: number };
    onBack: () => void;
};

const formatPrice = (value: number) =>
    new Intl.NumberFormat("fr-FR", {
        minimumFractionDigits: 3,
        maximumFractionDigits: 3,
    }).format(value);

const formatDistance = (meters: number) => {
    if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
    return `${Math.round(meters)} m`;
};

const fuelOrder = [1, 5, 2, 6, 3, 4]; // Gazole, SP95-E10, SP95, SP98, E85, GPLc

const FuelRow = ({ fuel, isBest }: { fuel: StationFuel; isBest: boolean }) => {
    const available = fuel.available && fuel.price !== null;

    return (
        <div
            style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "11px 14px",
                borderRadius: 14,
                background: isBest
                    ? "var(--brand-50)"
                    : available
                        ? "var(--surface-card)"
                        : "#f8fafc",
                border: `1.5px solid ${isBest ? "var(--brand-100)" : "var(--border)"}`,
                opacity: available ? 1 : 0.5,
            }}
        >
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                {isBest && (
                    <span
                        style={{
                            width: 6,
                            height: 6,
                            borderRadius: "50%",
                            background: "var(--brand)",
                            flexShrink: 0,
                        }}
                    />
                )}
                <div>
                    <p
                        style={{
                            fontSize: 13,
                            fontWeight: 700,
                            color: isBest ? "var(--brand)" : available ? "var(--text-1)" : "var(--text-3)",
                            lineHeight: 1.2,
                        }}
                    >
                        {fuel.shortName}
                    </p>
                    <p style={{ fontSize: 11, color: "var(--text-3)", marginTop: 1 }}>
                        {fuel.name}
                    </p>
                </div>
            </div>
            <div style={{ textAlign: "right" }}>
                {available && fuel.price !== null ? (
                    <>
                        <p
                            style={{
                                fontSize: isBest ? 17 : 15,
                                fontWeight: 800,
                                color: isBest ? "var(--brand)" : "var(--text-1)",
                                fontVariantNumeric: "tabular-nums",
                                letterSpacing: "-0.3px",
                            }}
                        >
                            {formatPrice(fuel.price)}
                        </p>
                        <p style={{ fontSize: 10, color: "var(--text-3)", fontWeight: 500 }}>€/L</p>
                    </>
                ) : (
                    <p style={{ fontSize: 12, color: "var(--text-3)", fontWeight: 500 }}>
                        Non disponible
                    </p>
                )}
            </div>
        </div>
    );
};

const StationDetail = ({ station, onBack }: StationDetailProps) => {
    const openInGoogleMaps = () => {
        window.open(
            `https://www.google.com/maps/search/?api=1&query=${station.coordinates.lat},${station.coordinates.lon}`,
            "_blank",
        );
    };

    // Sort fuels: available first (ordered by fuelOrder), then unavailable
    const sortedFuels = [...station.fuels].sort((a, b) => {
        const aAvail = a.available && a.price !== null;
        const bAvail = b.available && b.price !== null;
        if (aAvail !== bAvail) return aAvail ? -1 : 1;
        const aIdx = fuelOrder.indexOf(a.id);
        const bIdx = fuelOrder.indexOf(b.id);
        return (aIdx === -1 ? 99 : aIdx) - (bIdx === -1 ? 99 : bIdx);
    });

    const availableFuels = sortedFuels.filter((f) => f.available && f.price !== null);

    const lastUpdated = sortedFuels
        .map((f) => f.updatedAt)
        .filter((d): d is string => d !== null)
        .sort()
        .at(-1);

    const formattedDate = lastUpdated
        ? new Intl.DateTimeFormat("fr-FR", {
              day: "numeric",
              month: "long",
              hour: "2-digit",
              minute: "2-digit",
          }).format(new Date(lastUpdated))
        : null;

    return (
        <div className="panel-safe-bottom">
            {/* Back button */}
            <button type="button" className="panel-back" onClick={onBack}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="15 18 9 12 15 6" />
                </svg>
                Retour
            </button>

            {/* Station header */}
            <div style={{ marginBottom: 16 }}>
                <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12 }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                        {station.brand && (
                            <p style={{ fontSize: 11, fontWeight: 700, color: "var(--text-3)", letterSpacing: "0.07em", textTransform: "uppercase", marginBottom: 4 }}>
                                {station.brand}
                            </p>
                        )}
                        <h2 style={{ fontSize: 18, fontWeight: 800, color: "var(--text-1)", letterSpacing: "-0.4px", lineHeight: 1.2, marginBottom: 6 }}>
                            {station.name}
                        </h2>
                        {(station.address || station.city) && (
                            <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--text-3)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                                    <circle cx="12" cy="10" r="3" />
                                </svg>
                                <p style={{ fontSize: 12, color: "var(--text-3)" }}>
                                    {[station.address, station.city].filter(Boolean).join(", ")}
                                </p>
                            </div>
                        )}
                        {formattedDate && (
                            <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 4 }}>
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--text-3)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                                    <circle cx="12" cy="12" r="10" />
                                    <polyline points="12 6 12 12 16 14" />
                                </svg>
                                <p style={{ fontSize: 12, color: "var(--text-3)" }}>
                                    Actualisé le {formattedDate}
                                </p>
                            </div>
                        )}
                    </div>
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 4 }}>
                        {station.rank <= 3 && (
                            <span style={{ fontSize: 20 }}>
                                {station.rank === 1 ? "🥇" : station.rank === 2 ? "🥈" : "🥉"}
                            </span>
                        )}
                        {station.distanceToRoute > 0 && (
                            <span className="route-pill" style={{ fontSize: 11 }}>
                                {formatDistance(station.distanceToRoute)}
                            </span>
                        )}
                    </div>
                </div>
            </div>

            {/* Y aller button */}
            <button
                type="button"
                onClick={openInGoogleMaps}
                className="btn-primary"
                style={{ marginBottom: 20 }}
            >
                <span style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                        <polygon points="3 11 22 2 13 21 11 13 3 11" />
                    </svg>
                    Ouvrir dans Google Maps
                </span>
            </button>

            {/* Fuels section */}
            <div>
                <p className="section-label">
                    Carburants disponibles
                    {availableFuels.length > 0 && (
                        <span style={{ marginLeft: 6, color: "var(--brand)", fontWeight: 700 }}>
                            {availableFuels.length}
                        </span>
                    )}
                </p>
                {sortedFuels.length > 0 ? (
                    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                        {sortedFuels.map((fuel) => (
                            <FuelRow
                                key={fuel.id}
                                fuel={fuel}
                                isBest={false}
                            />
                        ))}
                    </div>
                ) : (
                    <p style={{ fontSize: 13, color: "var(--text-3)", textAlign: "center", padding: "20px 0" }}>
                        Aucune information de carburant disponible.
                    </p>
                )}
            </div>
        </div>
    );
};

export default StationDetail;
