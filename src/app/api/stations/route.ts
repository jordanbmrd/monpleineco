import { NextResponse } from "next/server";
import type { LatLng } from "@/lib/geo";
import { fetchStationsAround } from "@/lib/prixCarburants";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as {
      points?: LatLng[];
      fuelIds?: number[];
      rangeMeters?: number;
    };

    if (!body.points?.length) {
      return NextResponse.json(
        { error: "Aucun point d'itinéraire fourni." },
        { status: 400 },
      );
    }

    const rangeMeters =
      typeof body.rangeMeters === "number" ? body.rangeMeters : 5000;
    const fuelIds = Array.isArray(body.fuelIds) ? body.fuelIds : [];

    const stations = await fetchStationsAround(
      body.points,
      fuelIds,
      rangeMeters,
    );

    return NextResponse.json({ stations });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Erreur stations.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
