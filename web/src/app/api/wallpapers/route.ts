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

        // Rotation Logic: Equal exposure for same-day wallpapers
        // If sorting puts multiple wallpapers from the "Same Day" at the top,
        // we rotate which one is at index 0 every 90 minutes.
        if (wallpapers.length > 1 && wallpapers[0].releaseDate) {
            const topDate = new Date(wallpapers[0].releaseDate).toDateString();

            // Find all wallpapers belonging to this Latest Day
            let sameDayCount = 0;
            for (const wp of wallpapers) {
                if (wp.releaseDate && new Date(wp.releaseDate).toDateString() === topDate) {
                    sameDayCount++;
                } else {
                    break;
                }
            }

            if (sameDayCount > 1) {
                // Calculate 90-minute block index
                // Unix Timestamp (ms) / (1000 * 60 * 90)
                const now = Date.now();
                const intervalMs = 1000 * 60 * 90; // 90 minutes
                const blockIndex = Math.floor(now / intervalMs);

                // Determine which index (0 to sameDayCount-1) should be active
                const activeIndex = blockIndex % sameDayCount;

                if (activeIndex !== 0) {
                    // Swap the active item to the top
                    const activeItem = wallpapers[activeIndex];
                    wallpapers.splice(activeIndex, 1); // Remove from current spot
                    wallpapers.unshift(activeItem);    // Add to top

                    console.log(`[Rotation] Swapped index ${activeIndex} to top for 90min rotation.`);
                }
            }
        }

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
            },
        });

        return NextResponse.json(wallpaper);
    } catch (error) {
        console.error(error);
        return NextResponse.json({ error: "Error creating wallpaper" }, { status: 500 });
    }
}
