import { NextResponse } from "next/server";
import type { LatLng } from "@/lib/geo";
import { fetchRouteOrs } from "@/lib/ors";

export async function POST(request: Request) {
    try {
        const body = (await request.json()) as {
            start?: LatLng;
            end?: LatLng;
            avoidTolls?: boolean;
        };

        if (!body.start || !body.end) {
            return NextResponse.json(
                { error: "Coordonnées de trajet manquantes." },
                { status: 400 },
            );
        }

        const route = await fetchRouteOrs(
            body.start,
            body.end,
            body.avoidTolls ?? true,
        );
        return NextResponse.json(route);
    } catch (error) {
        const message =
            error instanceof Error ? error.message : "Erreur d'itinéraire.";
        return NextResponse.json({ error: message }, { status: 500 });
    }
}
