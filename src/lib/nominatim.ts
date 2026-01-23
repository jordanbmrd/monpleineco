import type { LatLng } from "./geo";

type NominatimResult = {
  lat: string;
  lon: string;
  display_name: string;
};

type NominatimSuggestion = {
  place_id: number;
  display_name: string;
};

const NOMINATIM_HEADERS = {
  "User-Agent": "monpleineco/1.0 (contact@monpleineco.local)",
  "Accept-Language": "fr",
};

export const geocodeAddress = async (query: string) => {
  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "1");
  url.searchParams.set("q", query);

  const response = await fetch(url.toString(), { headers: NOMINATIM_HEADERS });

  if (!response.ok) {
    throw new Error("Erreur lors de la géolocalisation de l'adresse.");
  }

  const data = (await response.json()) as NominatimResult[];
  if (!data.length) {
    throw new Error("Adresse introuvable.");
  }

  const result = data[0];
  const point: LatLng = {
    lat: Number.parseFloat(result.lat),
    lon: Number.parseFloat(result.lon),
  };

  return {
    point,
    label: result.display_name,
  };
};

export const autocompleteAddress = async (query: string) => {
  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "5");
  url.searchParams.set("q", query);

  const response = await fetch(url.toString(), { headers: NOMINATIM_HEADERS });
  if (!response.ok) {
    throw new Error("Erreur lors de la récupération des suggestions.");
  }

  const data = (await response.json()) as NominatimSuggestion[];
  return data.map((item) => ({
    id: item.place_id,
    label: item.display_name,
  }));
};
