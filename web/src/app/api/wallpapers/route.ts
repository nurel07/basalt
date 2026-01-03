import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const channelParam = searchParams.get("channel");
    const typeParam = searchParams.get("type");

    console.log("API v4 CALL RECEIVED", request.url);

    try {
        let where = {};
        if (channelParam) {
            const channels = channelParam.split(",");
            where = { channel: { in: channels } };
        }

        // Filter by published date if requested
        const publishedParam = searchParams.get("published");
        if (publishedParam === "true") {
            where = {
                ...where,
                releaseDate: {
                    lte: new Date(),
                },
            };
        }

        // Default to DESKTOP if not specified, unless explicit "ALL" is requested (optional for admin)
        // But for safety/compat, let's stick to: if type is provided use it, else default to DESKTOP
        const type = (typeParam === "MOBILE") ? "MOBILE" : "DESKTOP";

        where = {
            ...where,
            type
        };

        // Debug logging
        console.log("API v5 Debug:");
        console.log("- Request URL:", request.url);
        console.log("- Published Param:", publishedParam);
        console.log("- Type Param:", type);
        console.log("- Where Clause:", JSON.stringify(where, null, 2));

        const wallpapers = await prisma.wallpaper.findMany({
            where,
            orderBy: [
                { releaseDate: "desc" },
                { createdAt: "desc" },
            ],
        });



        console.log("- Wallpapers Found:", wallpapers.length);

        // Debug: Return X-Debug-Version header to verify deployment
        return NextResponse.json(wallpapers, {
            headers: {
                "X-Debug-Version": "v5",
            },
        });
    } catch (error) {
        console.error("Error fetching wallpapers:", error);
        return NextResponse.json({ error: "Error fetching wallpapers" }, { status: 500 });
    }
}

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { url, name, description, externalUrl, channel, releaseDate, artist, creationDate, genre, movement, dominantColors, tags, type, collectionId } = body;

        // Auto-assign order if adding to a collection
        let collectionOrder = 0;
        if (collectionId) {
            const lastWallpaper = await prisma.wallpaper.findFirst({
                where: { collectionId },
                orderBy: { collectionOrder: "desc" },
                select: { collectionOrder: true },
            });
            if (lastWallpaper) {
                collectionOrder = lastWallpaper.collectionOrder + 1;
            }
        }

        const wallpaper = await prisma.wallpaper.create({
            data: {
                url,
                name,
                description,
                externalUrl,
                channel: channel || "HUMAN",
                // Handled optional releaseDate in schema
                ...(releaseDate ? { releaseDate: new Date(releaseDate) } : {}),
                artist,
                creationDate,
                genre,
                movement,
                dominantColors,
                tags,
                type: type || "DESKTOP",
                collectionId,
                collectionOrder,
            },
        });

        return NextResponse.json(wallpaper);
    } catch (error) {
        console.error(error);
        return NextResponse.json({ error: "Error creating wallpaper" }, { status: 500 });
    }
}
