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
  { id: 1, label: "Gazole" },
  { id: 2, label: "SP95" },
  { id: 3, label: "E85" },
  { id: 4, label: "GPLc" },
  { id: 5, label: "SP95-E10" },
  { id: 6, label: "SP98" },
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
  const [searchMode, setSearchMode] = useState<"route" | "around">("route");
  const [addressQuery, setAddressQuery] = useState("");
  const [selectedFuelIds, setSelectedFuelIds] = useState<number[]>([6]);
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

  const handleFuelToggle = (id: number) => {
    setSelectedFuelIds((prev) =>
      prev.includes(id) ? prev.filter((fuel) => fuel !== id) : [...prev, id],
    );
  };

  const isReadyToSearch = useMemo(
    () => {
      if (searchMode === "route") {
        return Boolean(fromQuery.trim()) &&
          Boolean(toQuery.trim()) &&
          selectedFuelIds.length > 0;
      } else {
        return Boolean(addressQuery.trim()) && selectedFuelIds.length > 0;
      }
    },
    [searchMode, fromQuery, toQuery, addressQuery, selectedFuelIds],
  );

  const filteredStations = useMemo(() => {
    return stations.filter((s) => selectedBrands.includes(s.brand || "Autres"));
  }, [stations, selectedBrands]);

  const handleSwap = () => {
    setFromQuery(toQuery);
    setToQuery(fromQuery);
  };

  useEffect(() => {
    const handler = window.setTimeout(async () => {
      if (fromQuery.trim().length < 3) {
        setFromSuggestions([]);
        return;
      }
      try {
        setLoadingFromSuggestions(true);
        const data = await postJson<{ suggestions: Suggestion[] }>(
          "/api/autocomplete",
          { query: fromQuery },
        );
        setFromSuggestions(data.suggestions);
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
        const data = await postJson<{ suggestions: Suggestion[] }>(
          "/api/autocomplete",
          { query: toQuery },
        );
        setToSuggestions(data.suggestions);
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
        const data = await postJson<{ suggestions: Suggestion[] }>(
          "/api/autocomplete",
          { query: addressQuery },
        );
        setAddressSuggestions(data.suggestions);
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
      if (selectedFuelIds.length === 0) {
        throw new Error("Sélectionne au moins un carburant.");
      }

      if (searchMode === "route") {
        if (!fromQuery.trim() || !toQuery.trim()) {
          throw new Error("Merci de renseigner un départ et une arrivée.");
        }

        const [from, to] = await Promise.all([
          postJson<{ point: LatLng }>("/api/geocode", { query: fromQuery }),
          postJson<{ point: LatLng }>("/api/geocode", { query: toQuery }),
        ]);

        setStartPoint(from.point);
        setEndPoint(to.point);

        const routeData = await postJson<RouteData>("/api/route", {
          start: from.point,
          end: to.point,
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

        const { point } = await postJson<{ point: LatLng }>("/api/geocode", { query: addressQuery });
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
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-6 sm:gap-8 sm:px-6 sm:py-10">
        <header className="space-y-2 sm:space-y-3">
          <p className="text-[10px] uppercase tracking-[0.3em] text-slate-400 sm:text-xs">
            Mon Plein Éco
          </p>
          <h1 className="text-xl font-semibold text-slate-900 sm:text-2xl lg:text-3xl">
            Les stations essence les moins chères sur votre trajet.
          </h1>
          <p className="text-xs text-slate-500 sm:text-sm sm:max-w-2xl">
            Saisissez votre itinéraire, choisissez vos carburants et découvrez
            les stations les mieux placées en un coup d&apos;œil.
          </p>
        </header>

        <div className="grid gap-6 lg:grid-cols-[360px_1fr] lg:gap-8">
          <section className="glass-panel lg:sticky lg:top-6 lg:h-fit rounded-2xl p-4 sm:rounded-3xl sm:p-6">
            <form onSubmit={handleSubmit} className="space-y-4 sm:space-y-5">
              
              <div className="flex gap-4">
                <label className="flex items-center gap-2 text-sm font-medium text-slate-700 cursor-pointer">
                  <input
                    type="radio"
                    name="searchMode"
                    value="route"
                    checked={searchMode === "route"}
                    onChange={() => setSearchMode("route")}
                    className="h-4 w-4 border-slate-300 text-slate-900 focus:ring-slate-900"
                  />
                  Trajet
                </label>
                <label className="flex items-center gap-2 text-sm font-medium text-slate-700 cursor-pointer">
                  <input
                    type="radio"
                    name="searchMode"
                    value="around"
                    checked={searchMode === "around"}
                    onChange={() => setSearchMode("around")}
                    className="h-4 w-4 border-slate-300 text-slate-900 focus:ring-slate-900"
                  />
                  Autour de
                </label>
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
                        placeholder="Ex: 11 rue Jules Gautier, 92000 Nanterre"
                        className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-base text-slate-900 shadow-sm focus:border-slate-400 focus:outline-none sm:text-sm"
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
                    className="inline-flex items-center justify-center rounded-full border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-500 transition hover:border-slate-400 hover:text-slate-700 active:bg-slate-50 touch-manipulation"
                  >
                    Inverser départ / arrivée
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
                        placeholder="Ex: Montpellier"
                        className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-base text-slate-900 shadow-sm focus:border-slate-400 focus:outline-none sm:text-sm"
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
                  <div className="space-y-2">
                    <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
                      Itinéraires rapides
                    </p>
                    <div className="flex flex-wrap gap-2 text-xs">
                      {routePresets.map((preset) => (
                        <button
                          key={preset.label}
                          type="button"
                          onClick={() => {
                            setFromQuery(preset.from);
                            setToQuery(preset.to);
                          }}
                          className="rounded-full border border-slate-200 bg-white px-3 py-1.5 text-slate-600 transition hover:border-slate-400 hover:text-slate-800 active:bg-slate-50"
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
                      placeholder="Ex: 11 rue Jules Gautier, 92000 Nanterre"
                      className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-base text-slate-900 shadow-sm focus:border-slate-400 focus:outline-none sm:text-sm"
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

              <div className="space-y-2">
                <p className="text-sm font-medium text-slate-700">
                  Carburants
                </p>
                <div className="grid grid-cols-2 gap-2 text-xs sm:text-sm">
                  {fuelOptions.map((fuel) => (
                    <label
                      key={fuel.id}
                      className={`flex items-center gap-2 rounded-xl border px-3 py-2 transition ${selectedFuelIds.includes(fuel.id)
                        ? "border-slate-900 bg-slate-900 text-white"
                        : "border-slate-200 bg-white text-slate-600"
                        }`}
                    >
                      <input
                        type="checkbox"
                        checked={selectedFuelIds.includes(fuel.id)}
                        onChange={() => handleFuelToggle(fuel.id)}
                        className="hidden"
                      />
                      {fuel.label}
                    </label>
                  ))}
                </div>
              </div>
              {searchMode === "route" && (
                <div className="space-y-2">
                  <p className="text-sm font-medium text-slate-700">Trajet</p>
                  <div className="flex flex-col gap-2 text-sm">
                    <label
                      className={`flex items-center gap-2 rounded-xl border px-3 py-2 transition ${avoidTolls
                        ? "border-slate-900 bg-slate-900 text-white"
                        : "border-slate-200 bg-white text-slate-600"
                        }`}
                    >
                      <input
                        type="radio"
                        checked={avoidTolls}
                        onChange={() => setAvoidTolls(true)}
                        className="hidden"
                      />
                      Sans péages
                    </label>
                    <label
                      className={`flex items-center gap-2 rounded-xl border px-3 py-2 transition ${!avoidTolls
                        ? "border-slate-900 bg-slate-900 text-white"
                        : "border-slate-200 bg-white text-slate-600"
                        }`}
                    >
                      <input
                        type="radio"
                        checked={!avoidTolls}
                        onChange={() => setAvoidTolls(false)}
                        className="hidden"
                      />
                      Avec péages
                    </label>
                  </div>
                </div>
              )}
              {error && (
                <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {error}
                </div>
              )}
              <button
                type="submit"
                disabled={loading || !isReadyToSearch}
                className="w-full rounded-xl bg-slate-900 px-4 py-3.5 text-sm font-semibold text-white transition hover:bg-slate-800 active:bg-slate-950 disabled:cursor-not-allowed disabled:bg-slate-400 touch-manipulation"
              >
                {loading ? "Recherche en cours..." : "Chercher les stations"}
              </button>
            </form>

            <div className="mt-6 space-y-3 rounded-2xl border border-slate-200 bg-white px-4 py-3 text-xs text-slate-500">
              <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
                Résumé
              </p>
              <div className="grid gap-2">
                {searchMode === "route" && (
                  <p>
                    Option trajet: {avoidTolls ? "Sans péages" : "Avec péages"}
                  </p>
                )}
                <p>Carburants sélectionnés: {selectedFuelIds.length}</p>
                {route ? (
                  <>
                    <p>Distance estimée: {formatDistance(route.distance)}</p>
                    <p>Durée estimée: {formatDuration(route.duration)}</p>
                  </>
                ) : (
                  searchMode === "route" ? (
                    <p>Distance et durée calculées après recherche.</p>
                  ) : (
                    <p>Recherche autour de l&apos;adresse indiquée.</p>
                  )
                )}
              </div>
            </div>


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
              <div className="space-y-3 rounded-2xl border border-slate-200 bg-white px-4 py-3 text-xs text-slate-500">
                <div className="flex items-center justify-between">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
                    Marques
                  </p>
                  <button
                    type="button"
                    onClick={() =>
                      setSelectedBrands(
                        selectedBrands.length === availableBrands.length
                          ? []
                          : availableBrands,
                      )
                    }
                    className="text-[10px] text-slate-400 underline hover:text-slate-600"
                  >
                    {selectedBrands.length === availableBrands.length
                      ? "Tout décocher"
                      : "Tout cocher"}
                  </button>
                </div>
                <div className="flex flex-wrap gap-2">
                  {availableBrands.map((brand) => (
                    <button
                      key={brand}
                      type="button"
                      onClick={() => toggleBrand(brand)}
                      className={`rounded-lg border px-2 py-1 transition ${
                        selectedBrands.includes(brand)
                          ? "border-slate-900 bg-slate-900 text-white"
                          : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
                      }`}
                    >
                      {brand}
                    </button>
                  ))}
                </div>
              </div>
            )}
            <div>
              <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <h2 className="text-sm font-semibold text-slate-900">
                  {searchMode === "route" ? "Stations sur l'itinéraire" : "Stations aux alentours"}
                </h2>
                <div className="flex items-center gap-2 text-xs text-slate-400">
                  <span>
                    {filteredStations.length} résultat
                    {filteredStations.length > 1 ? "s" : ""}
                  </span>
                  <span className="hidden sm:inline">·</span>
                  <span className="hidden sm:inline">Top 10 surlignés</span>
                </div>
              </div>
              {loading ? (
                <div className="space-y-3">
                  {Array.from({ length: 5 }).map((_, index) => (
                    <div
                      key={`skeleton-${index}`}
                      className="h-20 animate-pulse rounded-2xl border border-slate-200 bg-white"
                    />
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
                <div className="rounded-2xl border border-dashed border-slate-200 bg-white px-6 py-10 text-sm text-slate-500">
                  {searchMode === "route"
                    ? "Lance une recherche pour afficher les stations sur ton trajet."
                    : "Lance une recherche pour afficher les stations aux alentours."}
                </div>
              )}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
