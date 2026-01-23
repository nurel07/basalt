import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = 'force-dynamic'; // Ensure this endpoint is not cached

export async function GET(request: Request) {
    try {
        const { searchParams } = new URL(request.url);
        const channelParam = searchParams.get("channel");

        let where: any = {};

        // Channel Filter
        if (channelParam) {
            const channels = channelParam.split(",");
            where.channel = { in: channels };
        }

        // Published Filter (always required for public random fetch)
        // If "published" is true, show only released items.
        // If not specified, we default to showing all? No, "Surprise me" should be safe.
        // Let's enforce "releaseDate <= now" if published=true is passed, or by default for random?
        // User requested "don't include future scheduled items".
        const publishedParam = searchParams.get("published");
        if (publishedParam === "true") {
            where.releaseDate = {
                lte: new Date(),
            };
        }

        // Exclude MOBILE items (Desktop only for random)
        where.type = "DESKTOP";

        // 1. Get Count
        const count = await prisma.wallpaper.count({ where });

        if (count === 0) {
            return NextResponse.json({ error: "No wallpapers found" }, { status: 404 });
        }

        // 2. Random Skip
        const skip = Math.floor(Math.random() * count);

        // 3. Fetch One
        const randomWallpaper = await prisma.wallpaper.findFirst({
            where,
            skip,
        });

        if (!randomWallpaper) {
            return NextResponse.json({ error: "Failed to fetch random wallpaper" }, { status: 404 });
        }

        return NextResponse.json(randomWallpaper);

    } catch (error) {
        console.error("Error fetching random wallpaper:", error);
        return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
}
