import type { LatLng } from "./geo";

/**
 * Uses the French government BAN API (Base Adresse Nationale)
 * https://adresse.data.gouv.fr/api-doc/adresse
 * Free, no key required, very precise for French addresses.
 */

type BanFeature = {
  properties: {
    label: string;
    id: string;
    score: number;
  };
  geometry: {
    coordinates: [number, number]; // [lon, lat]
  };
};

type BanResponse = {
  features: BanFeature[];
};

export const geocodeAddress = async (query: string) => {
  const url = new URL("https://api-adresse.data.gouv.fr/search/");
  url.searchParams.set("q", query);
  url.searchParams.set("limit", "1");

  const response = await fetch(url.toString());

  if (!response.ok) {
    throw new Error("Erreur lors de la géolocalisation de l'adresse.");
  }

  const data = (await response.json()) as BanResponse;
  if (!data.features.length) {
    throw new Error("Adresse introuvable.");
  }

  const feature = data.features[0];
  const [lon, lat] = feature.geometry.coordinates;
  const point: LatLng = { lat, lon };

  return {
    point,
    label: feature.properties.label,
  };
};

export const autocompleteAddress = async (query: string) => {
  const url = new URL("https://api-adresse.data.gouv.fr/search/");
  url.searchParams.set("q", query);
  url.searchParams.set("limit", "5");
  url.searchParams.set("autocomplete", "1");

  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error("Erreur lors de la récupération des suggestions.");
  }

  const data = (await response.json()) as BanResponse;
  return data.features.map((feature, index) => ({
    id: index,
    label: feature.properties.label,
  }));
};
