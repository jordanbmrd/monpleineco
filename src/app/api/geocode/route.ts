import { NextResponse } from "next/server";
import { geocodeAddress } from "@/lib/nominatim";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { query?: string };
    const query = body.query?.trim();
    if (!query) {
      return NextResponse.json(
        { error: "Adresse de recherche manquante." },
        { status: 400 },
      );
    }

    const result = await geocodeAddress(query);
    return NextResponse.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Erreur de géocodage.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
