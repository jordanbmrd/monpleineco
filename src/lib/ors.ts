import type { LatLng } from "./geo";

type OrsResponse = {
  features?: Array<{
    geometry?: { coordinates: [number, number][] };
    properties?: { summary?: { distance?: number; duration?: number } };
  }>;
};

export const fetchRouteOrs = async (
  start: LatLng,
  end: LatLng,
  avoidTolls: boolean,
) => {
  const apiKey = process.env.OPENROUTESERVICE_API_KEY;
  if (!apiKey) {
    throw new Error("Clé OpenRouteService manquante.");
  }

  const response = await fetch(
    "https://api.openrouteservice.org/v2/directions/driving-car/geojson",
    {
      method: "POST",
      headers: {
        Authorization: apiKey,
        "Content-Type": "application/json",
        Accept: "application/geo+json",
      },
      body: JSON.stringify({
        coordinates: [
          [start.lon, start.lat],
          [end.lon, end.lat],
        ],
        instructions: false,
        options: avoidTolls ? { avoid_features: ["tollways"] } : undefined,
      }),
    },
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `ORS ${response.status}: ${
        errorText || "Impossible de récupérer l'itinéraire ORS."
      }`,
    );
  }

  const data = (await response.json()) as OrsResponse;
  const feature = data.features?.[0];
  if (!feature?.geometry?.coordinates) {
    throw new Error("Aucun itinéraire ORS trouvé.");
  }

  return {
    coordinates: feature.geometry.coordinates,
    distance: feature.properties?.summary?.distance ?? 0,
    duration: feature.properties?.summary?.duration ?? 0,
  };
};
