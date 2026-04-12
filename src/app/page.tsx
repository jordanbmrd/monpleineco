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
import StationDetail from "@/components/StationDetail";
import type { MapViewRef } from "@/components/MapView";

const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-full w-full bg-slate-50 text-sm text-slate-400">
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

type RecentSearch = {
  mode: "route" | "around";
  label: string;
  from?: string;
  to?: string;
  address?: string;
  fuelId: number;
  avoidTolls?: boolean;
  route: RouteData | null;
  stations: StationWithMetrics[];
  availableBrands: string[];
  timestamp: number;
};

const RECENT_SEARCHES_KEY = "monpleineco_recent_searches";
const MAX_RECENT = 3;

const loadRecentSearches = (): RecentSearch[] => {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(RECENT_SEARCHES_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as RecentSearch[];
  } catch {
    return [];
  }
};

const saveRecentSearch = (search: RecentSearch) => {
  const existing = loadRecentSearches();
  const filtered = existing.filter((s) => s.label !== search.label);
  const updated = [search, ...filtered].slice(0, MAX_RECENT);
  localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
  return updated;
};

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
  const [selectedBrand, setSelectedBrand] = useState<string>("");
  const [sortBy, setSortBy] = useState<"price" | "distance">("price");
  const [recentSearches, setRecentSearches] = useState<RecentSearch[]>([]);

  // View state: 'form' = search form, 'results' = loading/results
  const [viewState, setViewState] = useState<"form" | "results">("form");
  const [panelMode, setPanelMode] = useState<"default" | "expanded" | "minimized">("default");
  const [selectedStation, setSelectedStation] = useState<StationWithMetrics | null>(null);

  useEffect(() => {
    if (viewState === "results") {
      setPanelMode("expanded");
    } else {
      setPanelMode("default");
    }
  }, [viewState]);

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
    const filtered = selectedBrand
      ? stations.filter((s) => (s.brand || "Autres") === selectedBrand)
      : stations;
    const sorted = [...filtered].sort((a, b) =>
      sortBy === "distance"
        ? a.distanceToRoute - b.distanceToRoute
        : a.bestPrice - b.bestPrice,
    );
    return sorted.map((s, i) => ({ ...s, rank: i + 1 }));
  }, [stations, selectedBrand, sortBy]);

  const handleSwap = () => {
    setFromQuery(toQuery);
    setToQuery(fromQuery);
  };

  const restoreRecentSearch = (recent: RecentSearch) => {
    setSearchMode(recent.mode);
    setSelectedFuelId(recent.fuelId);
    if (recent.mode === "route") {
      setFromQuery(recent.from ?? "");
      setToQuery(recent.to ?? "");
      setAvoidTolls(recent.avoidTolls ?? true);
    } else {
      setAddressQuery(recent.address ?? "");
    }
    setRoute(recent.route);
    setStations(recent.stations);
    setAvailableBrands(recent.availableBrands);
    setSelectedBrand("");
    setHasSearched(true);
    setError(null);
    setViewState("results");
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

  const [geolocating, setGeolocating] = useState(false);

  const handleGeolocate = () => {
    if (!navigator.geolocation) return;
    setGeolocating(true);
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const { latitude, longitude } = position.coords;
        try {
          const url = `https://photon.komoot.io/reverse?lon=${longitude}&lat=${latitude}&lang=fr`;
          const res = await fetch(url);
          if (res.ok) {
            const data = await res.json() as { features: Array<{ properties: { name?: string; street?: string; housenumber?: string; city?: string; postcode?: string } }> };
            if (data.features.length > 0) {
              const p = data.features[0].properties;
              const parts: string[] = [];
              if (p.name) parts.push(p.name);
              if (p.housenumber && p.street) parts.push(`${p.housenumber} ${p.street}`);
              else if (p.street) parts.push(p.street);
              if (p.postcode || p.city) parts.push([p.postcode, p.city].filter(Boolean).join(" "));
              setAddressQuery(parts.join(", ") || `${latitude.toFixed(5)}, ${longitude.toFixed(5)}`);
            } else {
              setAddressQuery(`${latitude.toFixed(5)}, ${longitude.toFixed(5)}`);
            }
          }
        } catch {
          setAddressQuery(`${latitude.toFixed(5)}, ${longitude.toFixed(5)}`);
        } finally {
          setGeolocating(false);
        }
      },
      () => {
        setGeolocating(false);
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  };

  useEffect(() => {
    setRecentSearches(loadRecentSearches());
  }, []);

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
    setShowFromSuggestions(false);
    setShowToSuggestions(false);
    setShowAddressSuggestions(false);
    setError(null);
    setHasSearched(true);
    setLoading(true);
    setViewState("results");

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
        setSelectedBrand("");

        setRecentSearches(saveRecentSearch({
          mode: "route",
          label: `${fromQuery.trim()} → ${toQuery.trim()}`,
          from: fromQuery.trim(),
          to: toQuery.trim(),
          fuelId: selectedFuelId,
          avoidTolls,
          route: routeData,
          stations: ranked,
          availableBrands: uniqueBrands,
          timestamp: Date.now(),
        }));
      } else {
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
            rangeMeters: 9999,
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
        setSelectedBrand("");

        setRecentSearches(saveRecentSearch({
          mode: "around",
          label: addressQuery.trim(),
          address: addressQuery.trim(),
          fuelId: selectedFuelId,
          route: null,
          stations: ranked,
          availableBrands: uniqueBrands,
          timestamp: Date.now(),
        }));
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
      {/* Full-screen map background */}
      <div className="map-fullscreen">
        <MapView
          route={route}
          stations={filteredStations}
          start={startPoint}
          end={endPoint}
          onMapReady={(ref) => {
            mapViewRef.current = ref;
          }}
        />
      </div>

      {/* Bottom sheet (mobile) / Floating panel (desktop) */}
      <div
        className={`panel-overlay${panelMode === "expanded" ? " panel-overlay--expanded" : ""}${panelMode === "minimized" ? " panel-overlay--minimized" : ""}`}
        onClick={panelMode === "minimized" ? () => setPanelMode("expanded") : undefined}
      >
        <div className="panel-handle-bar" />

        {panelMode === "minimized" ? (
          <div className="panel-minimized-strip">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg>
            <span>Voir les résultats</span>
          </div>
        ) : (
        <div className="panel-scroll">
          {viewState === "form" ? (
            /* ── Search form ── */
            <div className="panel-safe-bottom">

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
                    {recentSearches.filter((s) => s.mode === "route").length > 0 && (
                      <div>
                        <p className="section-label">Recherches récentes</p>
                        <div className="flex gap-2 overflow-x-auto scrollbar-hide">
                          {recentSearches.filter((s) => s.mode === "route").map((recent) => (
                            <button
                              key={recent.timestamp}
                              type="button"
                              onClick={() => restoreRecentSearch(recent)}
                              className="fuel-chip"
                            >
                              {recent.label}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </>
                ) : (
                  <>
                    <div className="space-y-2">
                      <label className="text-sm font-medium text-slate-700">
                        Adresse
                      </label>
                      <div className="relative">
                        <div className="input-with-action">
                          <input
                            value={addressQuery}
                            onChange={(event) => setAddressQuery(event.target.value)}
                            onFocus={() => setShowAddressSuggestions(true)}
                            onBlur={() =>
                              window.setTimeout(() => setShowAddressSuggestions(false), 150)
                            }
                            placeholder="Ville ou adresse"
                            className="search-input search-input--with-action"
                          />
                          <button
                            type="button"
                            onClick={handleGeolocate}
                            disabled={geolocating}
                            className="geolocate-btn"
                            aria-label="Me localiser"
                          >
                            {geolocating ? (
                              <svg className="animate-spin" width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="#94a3b8" strokeWidth="2.5" strokeDasharray="50" strokeLinecap="round" /></svg>
                            ) : (
                              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0f172a" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4" /><line x1="12" y1="2" x2="12" y2="6" /><line x1="12" y1="18" x2="12" y2="22" /><line x1="2" y1="12" x2="6" y2="12" /><line x1="18" y1="12" x2="22" y2="12" /></svg>
                            )}
                          </button>
                        </div>
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
                    {recentSearches.filter((s) => s.mode === "around").length > 0 && (
                      <div>
                        <p className="section-label">Recherches récentes</p>
                        <div className="flex gap-2 overflow-x-auto scrollbar-hide">
                          {recentSearches.filter((s) => s.mode === "around").map((recent) => (
                            <button
                              key={recent.timestamp}
                              type="button"
                              onClick={() => restoreRecentSearch(recent)}
                              className="fuel-chip"
                            >
                              {recent.label}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </>
                )}

                <div>
                  <p className="section-label">Carburant</p>
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

                {error && <div className="error-banner">{error}</div>}

                <button
                  type="submit"
                  disabled={loading || !isReadyToSearch}
                  className="btn-primary"
                >
                  {loading ? "Recherche en cours..." : "Rechercher"}
                </button>
              </form>
            </div>
          ) : (
            /* ── Results view ── */
            <div className="panel-safe-bottom">
              {selectedStation ? (
                <StationDetail
                  station={selectedStation}
                  onBack={() => setSelectedStation(null)}
                />
              ) : (
                <>
                  <div className="results-header">
                    <button
                      type="button"
                      className="panel-back"
                      onClick={() => { setViewState("form"); setSelectedStation(null); }}
                    >
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
                      Retour
                    </button>
                    {hasSearched && !loading && (
                      <span className="filter-count">
                        {filteredStations.length} résultat
                        {filteredStations.length > 1 ? "s" : ""}
                      </span>
                    )}
                  </div>

                  {error && <div className="error-banner mb-3">{error}</div>}

                  {route && (
                    <div className="flex gap-2 flex-wrap mb-4">
                      <span className="route-pill">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><line x1="2" y1="12" x2="22" y2="12"/><polyline points="15 5 22 12 15 19"/><polyline points="9 5 2 12 9 19"/></svg>
                        {formatDistance(route.distance)}
                      </span>
                      <span className="route-pill">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                        {formatDuration(route.duration)}
                      </span>
                    </div>
                  )}

                  {hasSearched && !loading && (
                    <div className="filter-bar">
                      <div className="filter-group">
                        <select
                          value={sortBy}
                          onChange={(e) => setSortBy(e.target.value as "price" | "distance")}
                          className="filter-select"
                        >
                          <option value="price">Prix croissant</option>
                          <option value="distance">Distance</option>
                        </select>
                        {availableBrands.length > 0 && (
                          <select
                            value={selectedBrand}
                            onChange={(e) => setSelectedBrand(e.target.value)}
                            className="filter-select"
                          >
                            <option value="">Toutes les marques</option>
                            {availableBrands.map((brand) => (
                              <option key={brand} value={brand}>{brand}</option>
                            ))}
                          </select>
                        )}
                      </div>
                    </div>
                  )}

                  {loading ? (
                    <div className="space-y-3">
                      {Array.from({ length: 4 }).map((_, index) => (
                        <div key={`skeleton-${index}`} className="skeleton" />
                      ))}
                    </div>
                  ) : (
                    <StationList
                      stations={filteredStations}
                      onSelect={(station) => {
                        setSelectedStation(station);
                        const isMobile = window.innerWidth < 1024;
                        if (isMobile) setPanelMode("default");
                        setTimeout(() => {
                          // On mobile, offset the marker upward so it sits in the
                          // visible area above the panel (58vh).
                          // panBy([0, positive]) moves the map down → marker goes up.
                          const offsetY = isMobile
                            ? Math.round(window.innerHeight * 0.29)
                            : 0;
                          mapViewRef.current?.openStationPopup(
                            station.coordinates.lat,
                            station.coordinates.lon,
                            offsetY,
                          );
                        }, 50);
                      }}
                      onCenterMap={(lat, lon) => {
                        setPanelMode("minimized");
                        setTimeout(() => {
                          mapViewRef.current?.openStationPopup(lat, lon);
                        }, 400);
                      }}
                    />
                  )}
                </>
              )}
            </div>
          )}
        </div>
        )}
      </div>
    </div>
  );
}
