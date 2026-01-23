"use client";

import { useEffect, useMemo, useRef, useImperativeHandle, forwardRef } from "react";
import {
    MapContainer,
    Marker,
    Polyline,
    Popup,
    TileLayer,
    useMap,
} from "react-leaflet";
import L from "leaflet";
import type { Station } from "@/lib/prixCarburants";
import type { LatLng } from "@/lib/geo";

type RouteData = {
    coordinates: [number, number][];
};

export type MapViewRef = {
    centerOnStation: (lat: number, lon: number) => void;
};

type MapViewProps = {
    route: RouteData | null;
    stations: Array<
        Station & { bestPrice: number; bestFuelLabel: string; rank: number }
    >;
    start: LatLng | null;
    end: LatLng | null;
    onMapReady?: (ref: MapViewRef) => void;
};

const formatPrice = (value: number) =>
    new Intl.NumberFormat("fr-FR", {
        minimumFractionDigits: 3,
        maximumFractionDigits: 3,
    }).format(value);

const FitBounds = ({
    route,
    stations,
    start,
    end,
}: {
    route: RouteData | null;
    stations: MapViewProps["stations"];
    start: LatLng | null;
    end: LatLng | null;
}) => {
    const map = useMap();

    useEffect(() => {
        const points: L.LatLngExpression[] = [];
        if (route?.coordinates?.length) {
            route.coordinates.forEach(([lon, lat]) => points.push([lat, lon]));
        }
        stations.forEach((station) =>
            points.push([station.coordinates.lat, station.coordinates.lon]),
        );
        if (start) {
            points.push([start.lat, start.lon]);
        }
        if (end) {
            points.push([end.lat, end.lon]);
        }
        if (points.length) {
            const bounds = L.latLngBounds(points);
            map.fitBounds(bounds, { padding: [30, 30] });
        }
    }, [map, route, stations, start, end]);

    return null;
};

const MapController = forwardRef<
    { centerOnStation: (lat: number, lon: number) => void },
    { mapRef: React.MutableRefObject<L.Map | null>; onReady?: (ref: { centerOnStation: (lat: number, lon: number) => void }) => void }
>(({ mapRef, onReady }, ref) => {
    const map = useMap();
    mapRef.current = map;

    const centerOnStation = (lat: number, lon: number) => {
        map.setView([lat, lon], 15, { animate: true, duration: 0.5 });
    };

    useImperativeHandle(ref, () => ({
        centerOnStation,
    }));

    useEffect(() => {
        if (onReady) {
            onReady({ centerOnStation });
        }
    }, [onReady]);

    return null;
});
MapController.displayName = "MapController";

const MapView = ({ route, stations, start, end, onMapReady }: MapViewProps) => {
    const mapRef = useRef<L.Map | null>(null);
    const controllerRef = useRef<{ centerOnStation: (lat: number, lon: number) => void }>(null);

    useEffect(() => {
        L.Icon.Default.mergeOptions({
            iconUrl: "/leaflet/marker-icon.png",
            iconRetinaUrl: "/leaflet/marker-icon-2x.png",
            shadowUrl: "/leaflet/marker-shadow.png",
        });
    }, []);

    const polyline = useMemo(() => {
        if (!route?.coordinates?.length) {
            return [];
        }
        return route.coordinates.map(([lon, lat]) => [lat, lon]) as [
            number,
            number,
        ][];
    }, [route]);

    return (
        <MapContainer
            center={[48.8566, 2.3522]}
            zoom={6}
            scrollWheelZoom
            className="map-container"
        >
            <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <MapController
                ref={controllerRef}
                mapRef={mapRef}
                onReady={(ref) => {
                    controllerRef.current = ref;
                    if (onMapReady) {
                        onMapReady(ref);
                    }
                }}
            />
            {polyline.length > 0 && (
                <Polyline positions={polyline} pathOptions={{ color: "#0f172a" }} />
            )}
            {start && (
                <Marker position={[start.lat, start.lon]}>
                    <Popup>Départ</Popup>
                </Marker>
            )}
            {end && (
                <Marker position={[end.lat, end.lon]}>
                    <Popup>Arrivée</Popup>
                </Marker>
            )}
            {stations.map((station) => (
                <Marker
                    key={station.id}
                    position={[station.coordinates.lat, station.coordinates.lon]}
                    icon={L.divIcon({
                        className: `station-pin ${station.rank <= 10 ? "station-pin--top" : ""
                            }`,
                        html: `<span class="station-pin__label ${station.rank <= 10 ? "station-pin__label--top" : ""
                            }">${station.rank}</span>`,
                        iconSize: [28, 28],
                        iconAnchor: [14, 28],
                        popupAnchor: [0, -26],
                    })}
                >
                    <Popup>
                        <div className="space-y-1">
                            <p className="text-sm font-semibold">
                                #{station.rank} · {station.name}
                            </p>
                            <p className="text-xs text-slate-500">
                                {station.brand ?? "Station indépendante"}
                            </p>
                            <p className="text-sm font-semibold text-slate-900">
                                {formatPrice(station.bestPrice)} €/L · {station.bestFuelLabel}
                            </p>
                        </div>
                    </Popup>
                </Marker>
            ))}
            <FitBounds route={route} stations={stations} start={start} end={end} />
        </MapContainer>
    );
};

export default MapView;
