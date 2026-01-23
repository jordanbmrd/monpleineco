import { NextResponse } from "next/server";
import { autocompleteAddress } from "@/lib/nominatim";

export async function POST(request: Request) {
    try {
        const body = (await request.json()) as { query?: string };
        const query = body.query?.trim();
        if (!query || query.length < 3) {
            return NextResponse.json({ suggestions: [] });
        }

        const suggestions = await autocompleteAddress(query);
        return NextResponse.json({ suggestions });
    } catch (error) {
        const message =
            error instanceof Error ? error.message : "Erreur de suggestion.";
        return NextResponse.json({ error: message }, { status: 500 });
    }
}
