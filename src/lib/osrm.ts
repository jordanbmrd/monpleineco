import type { LatLng } from "./geo";

type OsrmResponse = {
  routes?: Array<{
    geometry: { coordinates: [number, number][] };
    distance: number;
    duration: number;
  }>;
};

export const fetchRoute = async (start: LatLng, end: LatLng) => {
  const url = new URL(
    `https://router.project-osrm.org/route/v1/driving/${start.lon},${start.lat};${end.lon},${end.lat}`,
  );
  url.searchParams.set("overview", "full");
  url.searchParams.set("geometries", "geojson");

  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error("Impossible de récupérer l'itinéraire.");
  }

  const data = (await response.json()) as OsrmResponse;
  if (!data.routes || !data.routes.length) {
    throw new Error("Aucun itinéraire trouvé.");
  }

  const route = data.routes[0];
  return {
    coordinates: route.geometry.coordinates,
    distance: route.distance,
    duration: route.duration,
  };
};
