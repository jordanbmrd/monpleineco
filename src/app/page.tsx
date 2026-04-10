"use client";

import { useEffect, useMemo, useState, useRef } from "react";
import dynamic from "next/dynamic";
import type { Station } from "@/lib/prixCarburants";
import type { LatLng } from "@/lib/geo";
import {
  distancePointToPolylineMeters,
  sampleRoutePoints,
} from "@/lib/geo";
import StationList from "@/components/StationList";
import type { MapViewRef } from "@/components/MapView";

const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => (
    <div className="map-container flex items-center justify-center bg-white text-sm text-slate-400">
      Chargement de la carte...
    </div>
  ),
});

type RouteData = {
  coordinates: [number, number][];
  distance: number;
  duration: number;
};

type StationWithMetrics = Station & {
  bestPrice: number;
  bestFuelLabel: string;
  distanceToRoute: number;
  rank: number;
};

type Suggestion = {
  id: number;
  label: string;
};

const fuelOptions = [
  { id: 5, label: "SP95-E10" },
  { id: 6, label: "SP98" },
  { id: 1, label: "Gazole" },
  { id: 2, label: "SP95" },
  { id: 3, label: "E85" },
  { id: 4, label: "GPLc" },
];

const routePresets = [
  {
    label: "Nantes → Le Mans",
    from: "Gare de Nantes",
    to: "Gare du Mans",
  },
  {
    label: "Paris → Le Mans",
    from: "Gare Montparnasse, Paris",
    to: "Gare du Mans",
  },
];

const postJson = async <T,>(url: string, body: unknown): Promise<T> => {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = (await response.json()) as { error?: string } & T;
  if (!response.ok) {
    throw new Error(data.error ?? "Erreur de traitement.");
  }
  return data;
};

const formatDuration = (seconds: number) => {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.round((seconds % 3600) / 60);
  if (hours <= 0) {
    return `${minutes} min`;
  }
  return `${hours} h ${minutes.toString().padStart(2, "0")} min`;
};

const formatDistance = (meters: number) =>
  `${(meters / 1000).toFixed(1)} km`;

export default function Home() {
  const [fromQuery, setFromQuery] = useState("");
  const [toQuery, setToQuery] = useState("");
  const [searchMode, setSearchMode] = useState<"route" | "around">("around");
  const [addressQuery, setAddressQuery] = useState("");
  const [selectedFuelId, setSelectedFuelId] = useState<number>(5);
  const [route, setRoute] = useState<RouteData | null>(null);
  const [stations, setStations] = useState<StationWithMetrics[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [startPoint, setStartPoint] = useState<LatLng | null>(null);
  const [endPoint, setEndPoint] = useState<LatLng | null>(null);
  const [fromSuggestions, setFromSuggestions] = useState<Suggestion[]>([]);
  const [toSuggestions, setToSuggestions] = useState<Suggestion[]>([]);
  const [addressSuggestions, setAddressSuggestions] = useState<Suggestion[]>([]);
  const [showFromSuggestions, setShowFromSuggestions] = useState(false);
  const [showToSuggestions, setShowToSuggestions] = useState(false);
  const [showAddressSuggestions, setShowAddressSuggestions] = useState(false);
  const [loadingFromSuggestions, setLoadingFromSuggestions] = useState(false);
  const [loadingToSuggestions, setLoadingToSuggestions] = useState(false);
  const [loadingAddressSuggestions, setLoadingAddressSuggestions] = useState(false);
  const [avoidTolls, setAvoidTolls] = useState(true);
  const mapViewRef = useRef<MapViewRef | null>(null);
  const [hasSearched, setHasSearched] = useState(false);

  const [availableBrands, setAvailableBrands] = useState<string[]>([]);
  const [selectedBrands, setSelectedBrands] = useState<string[]>([]);

  const toggleBrand = (brand: string) => {
    setSelectedBrands((prev) =>
      prev.includes(brand) ? prev.filter((b) => b !== brand) : [...prev, brand],
    );
  };

  const handleFuelSelect = (id: number) => {
    setSelectedFuelId(id);
  };

  const isReadyToSearch = useMemo(
    () => {
      if (searchMode === "route") {
        return Boolean(fromQuery.trim()) &&
          Boolean(toQuery.trim()) &&
          selectedFuelId > 0;
      } else {
        return Boolean(addressQuery.trim()) && selectedFuelId > 0;
      }
    },
    [searchMode, fromQuery, toQuery, addressQuery, selectedFuelId],
  );

  const filteredStations = useMemo(() => {
    return stations.filter((s) => selectedBrands.includes(s.brand || "Autres"));
  }, [stations, selectedBrands]);

  const handleSwap = () => {
    setFromQuery(toQuery);
    setToQuery(fromQuery);
  };

  const fetchSuggestions = async (query: string): Promise<Suggestion[]> => {
    const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&limit=5&lang=fr&lat=46.6&lon=2.2`;
    const res = await fetch(url);
    if (!res.ok) return [];
    const data = await res.json() as { features: Array<{ properties: { name?: string; street?: string; housenumber?: string; city?: string; postcode?: string; country?: string; osm_value?: string } }> };
    return data.features.map((f, i) => {
      const p = f.properties;
      const parts: string[] = [];
      if (p.name) parts.push(p.name);
      if (p.housenumber && p.street) parts.push(`${p.housenumber} ${p.street}`);
      else if (p.street) parts.push(p.street);
      if (p.postcode || p.city) parts.push([p.postcode, p.city].filter(Boolean).join(" "));
      return { id: i, label: parts.join(", ") || "Lieu inconnu" };
    });
  };

  const geocodeClient = async (query: string): Promise<LatLng> => {
    const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&limit=1&lang=fr&lat=46.6&lon=2.2`;
    const res = await fetch(url);
    if (!res.ok) throw new Error("Erreur lors de la géolocalisation.");
    const data = await res.json() as { features: Array<{ geometry: { coordinates: [number, number] } }> };
    if (!data.features.length) throw new Error("Adresse introuvable.");
    const [lon, lat] = data.features[0].geometry.coordinates;
    return { lat, lon };
  };

  useEffect(() => {
    const handler = window.setTimeout(async () => {
      if (fromQuery.trim().length < 3) {
        setFromSuggestions([]);
        return;
      }
      try {
        setLoadingFromSuggestions(true);
        setFromSuggestions(await fetchSuggestions(fromQuery));
      } catch {
        setFromSuggestions([]);
      } finally {
        setLoadingFromSuggestions(false);
      }
    }, 250);
    return () => window.clearTimeout(handler);
  }, [fromQuery]);

  useEffect(() => {
    const handler = window.setTimeout(async () => {
      if (toQuery.trim().length < 3) {
        setToSuggestions([]);
        return;
      }
      try {
        setLoadingToSuggestions(true);
        setToSuggestions(await fetchSuggestions(toQuery));
      } catch {
        setToSuggestions([]);
      } finally {
        setLoadingToSuggestions(false);
      }
    }, 250);
    return () => window.clearTimeout(handler);
  }, [toQuery]);

  useEffect(() => {
    const handler = window.setTimeout(async () => {
      if (addressQuery.trim().length < 3) {
        setAddressSuggestions([]);
        return;
      }
      try {
        setLoadingAddressSuggestions(true);
        setAddressSuggestions(await fetchSuggestions(addressQuery));
      } catch {
        setAddressSuggestions([]);
      } finally {
        setLoadingAddressSuggestions(false);
      }
    }, 250);
    return () => window.clearTimeout(handler);
  }, [addressQuery]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setHasSearched(true);
    setLoading(true);

    try {
      const selectedFuelIds = [selectedFuelId];

      if (searchMode === "route") {
        if (!fromQuery.trim() || !toQuery.trim()) {
          throw new Error("Merci de renseigner un départ et une arrivée.");
        }

        const [fromPoint, toPoint] = await Promise.all([
          geocodeClient(fromQuery),
          geocodeClient(toQuery),
        ]);

        setStartPoint(fromPoint);
        setEndPoint(toPoint);

        const routeData = await postJson<RouteData>("/api/route", {
          start: fromPoint,
          end: toPoint,
          avoidTolls,
        });
        setRoute(routeData);

        const targetCalls = Math.min(40, Math.max(12, Math.ceil(routeData.distance / 15000)));
        const spacingMeters = Math.max(6000, routeData.distance / targetCalls);
        const sampledPoints = sampleRoutePoints(
          routeData.coordinates.map(([lon, lat]) => ({ lat, lon })),
          spacingMeters,
        );

        const stationData = await postJson<{ stations: Station[] }>(
          "/api/stations",
          {
            points: sampledPoints,
            fuelIds: selectedFuelIds,
            rangeMeters: 9999,
          },
        );

        const routeLineNow = routeData.coordinates.map(([lon, lat]) => ({
          lat,
          lon,
        }));
        const enriched = stationData.stations
          .map((station) => {
            const candidates = station.fuels.filter(
              (fuel): fuel is (typeof station.fuels)[number] & { price: number } =>
                selectedFuelIds.includes(fuel.id) &&
                fuel.available &&
                typeof fuel.price === "number",
            );
            if (!candidates.length) {
              return null;
            }
            const best = candidates.reduce((acc, fuel) =>
              fuel.price < acc.price ? fuel : acc,
            );
            const distanceToRoute =
              routeLineNow.length > 1
                ? distancePointToPolylineMeters(
                  station.coordinates,
                  routeLineNow,
                )
                : Number.POSITIVE_INFINITY;
            return {
              ...station,
              bestPrice: best.price ?? 0,
              bestFuelLabel: best.shortName,
              distanceToRoute,
            };
          })
          .filter((station): station is StationWithMetrics => Boolean(station))
          .filter((station) => station.distanceToRoute <= 5000)
          .sort((a, b) => a.bestPrice - b.bestPrice);

        const ranked = enriched.map((station, index) => ({
          ...station,
          rank: index + 1,
        }));

        if (ranked.length === 0 && stationData.stations.length > 0) {
          console.warn(`Aucune station trouvée après filtrage. Stations brutes: ${stationData.stations.length}, Points échantillonnés: ${sampledPoints.length}`);
        }

        setStations(ranked);

        const uniqueBrands = Array.from(
          new Set(ranked.map((s) => s.brand || "Autres"))
        ).sort();
        setAvailableBrands(uniqueBrands);
        setSelectedBrands(uniqueBrands);
      } else {
        // Mode "Autour de"
        if (!addressQuery.trim()) {
          throw new Error("Merci de renseigner une adresse.");
        }

        const point = await geocodeClient(addressQuery);
        setStartPoint(point);
        setEndPoint(null);
        setRoute(null);

        const stationData = await postJson<{ stations: Station[] }>(
          "/api/stations",
          {
            points: [point],
            fuelIds: selectedFuelIds,
            rangeMeters: 9999, // Max allowed by API is 10km
          },
        );

        const enriched = stationData.stations
          .map((station) => {
            const candidates = station.fuels.filter(
              (fuel): fuel is (typeof station.fuels)[number] & { price: number } =>
                selectedFuelIds.includes(fuel.id) &&
                fuel.available &&
                typeof fuel.price === "number",
            );
            if (!candidates.length) {
              return null;
            }
            const best = candidates.reduce((acc, fuel) =>
              fuel.price < acc.price ? fuel : acc,
            );
            
            // Distance à vol d'oiseau depuis le point central
            // (approximation simple ou calcul précis si nécessaire, mais ici on n'a pas de route)
            // On peut utiliser distancePointToPolylineMeters avec un point unique si on veut, 
            // ou juste laisser distanceToRoute à 0 car ce n'est pas pertinent.
            // Mais pour le tri/affichage, on pourrait vouloir la distance au point.
            // Pour l'instant, on met 0.
            
            return {
              ...station,
              bestPrice: best.price ?? 0,
              bestFuelLabel: best.shortName,
              distanceToRoute: 0, 
            };
          })
          .filter((station): station is StationWithMetrics => Boolean(station))
          .sort((a, b) => a.bestPrice - b.bestPrice);

        const ranked = enriched.map((station, index) => ({
          ...station,
          rank: index + 1,
        }));

        setStations(ranked);

        const uniqueBrands = Array.from(
          new Set(ranked.map((s) => s.brand || "Autres"))
        ).sort();
        setAvailableBrands(uniqueBrands);
        setSelectedBrands(uniqueBrands);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur inconnue.");
      setStations([]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="mx-auto max-w-6xl flex items-center justify-between px-4 py-3 sm:px-6">
          <h1 className="text-lg font-bold text-slate-900 tracking-tight">
            <span className="mr-1">⛽</span> Mon Plein Éco
          </h1>
          <span className="text-xs text-slate-400 hidden sm:inline">Trouvez le carburant le moins cher</span>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 pb-6 sm:px-6 safe-bottom">
        <div className="grid gap-4 py-4 lg:grid-cols-[380px_1fr] lg:gap-6 lg:py-6">
          <section className="search-panel">
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="segmented-control">
                <button
                  type="button"
                  onClick={() => setSearchMode("around")}
                  className={`segment ${searchMode === "around" ? "segment--active" : ""}`}
                >
                  Autour de moi
                </button>
                <button
                  type="button"
                  onClick={() => setSearchMode("route")}
                  className={`segment ${searchMode === "route" ? "segment--active" : ""}`}
                >
                  Sur un trajet
                </button>
              </div>

              {searchMode === "route" ? (
                <>
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-slate-700">
                      Départ
                    </label>
                    <div className="relative">
                      <input
                        value={fromQuery}
                        onChange={(event) => setFromQuery(event.target.value)}
                        onFocus={() => setShowFromSuggestions(true)}
                        onBlur={() =>
                          window.setTimeout(() => setShowFromSuggestions(false), 150)
                        }
                        placeholder="Ville ou adresse de départ"
                        className="search-input"
                      />
                      {showFromSuggestions && fromQuery.trim().length >= 3 && (
                        <div className="autocomplete-panel">
                          <div className="autocomplete-header">Suggestions</div>
                          {loadingFromSuggestions ? (
                            <div className="autocomplete-empty">
                              Recherche en cours...
                            </div>
                          ) : fromSuggestions.length > 0 ? (
                            <div className="autocomplete-list">
                              {fromSuggestions.map((suggestion) => (
                                <div
                                  key={suggestion.id}
                                  className="autocomplete-item"
                                  onMouseDown={() => {
                                    setFromQuery(suggestion.label);
                                    setFromSuggestions([]);
                                    setShowFromSuggestions(false);
                                  }}
                                >
                                  {suggestion.label}
                                </div>
                              ))}
                            </div>
                          ) : (
                            <div className="autocomplete-empty">
                              Aucun résultat trouvé.
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={handleSwap}
                    className="mx-auto flex items-center justify-center w-10 h-10 rounded-full bg-slate-100 text-slate-500 transition active:scale-95 active:bg-slate-200 touch-manipulation"
                    aria-label="Inverser départ / arrivée"
                  >
                    ↕
                  </button>
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-slate-700">
                      Arrivée
                    </label>
                    <div className="relative">
                      <input
                        value={toQuery}
                        onChange={(event) => setToQuery(event.target.value)}
                        onFocus={() => setShowToSuggestions(true)}
                        onBlur={() =>
                          window.setTimeout(() => setShowToSuggestions(false), 150)
                        }
                        placeholder="Ville ou adresse d'arrivée"
                        className="search-input"
                      />
                      {showToSuggestions && toQuery.trim().length >= 3 && (
                        <div className="autocomplete-panel">
                          <div className="autocomplete-header">Suggestions</div>
                          {loadingToSuggestions ? (
                            <div className="autocomplete-empty">
                              Recherche en cours...
                            </div>
                          ) : toSuggestions.length > 0 ? (
                            <div className="autocomplete-list">
                              {toSuggestions.map((suggestion) => (
                                <div
                                  key={suggestion.id}
                                  className="autocomplete-item"
                                  onMouseDown={() => {
                                    setToQuery(suggestion.label);
                                    setToSuggestions([]);
                                    setShowToSuggestions(false);
                                  }}
                                >
                                  {suggestion.label}
                                </div>
                              ))}
                            </div>
                          ) : (
                            <div className="autocomplete-empty">
                              Aucun résultat trouvé.
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                  <div>
                    <p className="section-label">Itinéraires rapides</p>
                    <div className="flex gap-2 overflow-x-auto scrollbar-hide">
                      {routePresets.map((preset) => (
                        <button
                          key={preset.label}
                          type="button"
                          onClick={() => {
                            setFromQuery(preset.from);
                            setToQuery(preset.to);
                          }}
                          className="fuel-chip"
                        >
                          {preset.label}
                        </button>
                      ))}
                    </div>
                  </div>
                </>
              ) : (
                <div className="space-y-2">
                  <label className="text-sm font-medium text-slate-700">
                    Adresse
                  </label>
                  <div className="relative">
                    <input
                      value={addressQuery}
                      onChange={(event) => setAddressQuery(event.target.value)}
                      onFocus={() => setShowAddressSuggestions(true)}
                      onBlur={() =>
                        window.setTimeout(() => setShowAddressSuggestions(false), 150)
                      }
                      placeholder="Ville ou adresse"
                      className="search-input"
                    />
                    {showAddressSuggestions && addressQuery.trim().length >= 3 && (
                      <div className="autocomplete-panel">
                        <div className="autocomplete-header">Suggestions</div>
                        {loadingAddressSuggestions ? (
                          <div className="autocomplete-empty">
                            Recherche en cours...
                          </div>
                        ) : addressSuggestions.length > 0 ? (
                          <div className="autocomplete-list">
                            {addressSuggestions.map((suggestion) => (
                              <div
                                key={suggestion.id}
                                className="autocomplete-item"
                                onMouseDown={() => {
                                  setAddressQuery(suggestion.label);
                                  setAddressSuggestions([]);
                                  setShowAddressSuggestions(false);
                                }}
                              >
                                {suggestion.label}
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="autocomplete-empty">
                            Aucun résultat trouvé.
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              )}

              <div>
                <p className="section-label">Carburants</p>
                <div className="flex gap-2 flex-wrap">
                  {fuelOptions.map((fuel) => (
                    <button
                      key={fuel.id}
                      type="button"
                      onClick={() => handleFuelSelect(fuel.id)}
                      className={`fuel-chip ${selectedFuelId === fuel.id ? "fuel-chip--selected" : ""}`}
                    >
                      {fuel.label}
                    </button>
                  ))}
                </div>
              </div>
              {searchMode === "route" && (
                <div>
                  <p className="section-label">Options</p>
                  <div className="flex gap-2">
                    <label className={`toggle-chip ${avoidTolls ? "toggle-chip--selected" : ""}`}>
                      <input type="radio" checked={avoidTolls} onChange={() => setAvoidTolls(true)} className="hidden" />
                      Sans péages
                    </label>
                    <label className={`toggle-chip ${!avoidTolls ? "toggle-chip--selected" : ""}`}>
                      <input type="radio" checked={!avoidTolls} onChange={() => setAvoidTolls(false)} className="hidden" />
                      Avec péages
                    </label>
                  </div>
                </div>
              )}
              {error && <div className="error-banner">{error}</div>}
              <button
                type="submit"
                disabled={loading || !isReadyToSearch}
                className="btn-primary"
              >
                {loading ? "Recherche en cours..." : "Rechercher"}
              </button>
            </form>

            {route && (
              <div className="mt-4 flex gap-2 flex-wrap">
                <span className="route-pill">📏 {formatDistance(route.distance)}</span>
                <span className="route-pill">⏱️ {formatDuration(route.duration)}</span>
              </div>
            )}
          </section>

          <section className="space-y-4 sm:space-y-6">
            <MapView
              route={route}
              stations={filteredStations}
              start={startPoint}
              end={endPoint}
              onMapReady={(ref) => {
                mapViewRef.current = ref;
              }}
            />
            {hasSearched && availableBrands.length > 0 && (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <p className="section-label mb-0">Marques</p>
                  <button
                    type="button"
                    onClick={() =>
                      setSelectedBrands(
                        selectedBrands.length === availableBrands.length
                          ? []
                          : availableBrands,
                      )
                    }
                    className="text-xs text-slate-400 font-medium"
                  >
                    {selectedBrands.length === availableBrands.length
                      ? "Tout décocher"
                      : "Tout cocher"}
                  </button>
                </div>
                <div className="flex gap-2 flex-wrap">
                  {availableBrands.map((brand) => (
                    <button
                      key={brand}
                      type="button"
                      onClick={() => toggleBrand(brand)}
                      className={`brand-tag ${selectedBrands.includes(brand) ? "brand-tag--selected" : ""}`}
                    >
                      {brand}
                    </button>
                  ))}
                </div>
              </div>
            )}
            <div>
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-sm font-semibold text-slate-900">
                  {searchMode === "route" ? "Stations sur le trajet" : "Stations proches"}
                </h2>
                {hasSearched && (
                  <span className="text-xs text-slate-400 font-medium">
                    {filteredStations.length} résultat{filteredStations.length > 1 ? "s" : ""}
                  </span>
                )}
              </div>
              {loading ? (
                <div className="space-y-3">
                  {Array.from({ length: 4 }).map((_, index) => (
                    <div key={`skeleton-${index}`} className="skeleton" />
                  ))}
                </div>
              ) : hasSearched ? (
                <StationList
                  stations={filteredStations}
                  onCenterMap={(lat, lon) => {
                    mapViewRef.current?.centerOnStation(lat, lon);
                  }}
                />
              ) : (
                <div className="empty-state">
                  <div className="text-3xl mb-3">⛽</div>
                  <p className="font-medium text-slate-600 mb-1">Prêt à chercher</p>
                  <p className="text-sm">
                    {searchMode === "route"
                      ? "Indique ton trajet pour trouver les stations les moins chères."
                      : "Indique une adresse pour trouver les stations autour de toi."}
                  </p>
                </div>
              )}
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
