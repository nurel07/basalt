import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
    try {
        // Fetch ALL "Fine Art" (HUMAN channel) wallpapers released on or before today
        // We need 'findMany' to handle the rotation logic if there are multiple for today.
        const wallpapers = await prisma.wallpaper.findMany({
            where: {
                releaseDate: {
                    lte: new Date(),
                },
                channel: "HUMAN",
            },
            orderBy: [
                { releaseDate: "desc" },
                { createdAt: "desc" },
            ],
            // Optimization: We theoretically only need the top few to determine "Today's", 
            // but to be safe and simple we can fetch a small batch, e.g., 20.
            take: 20,
        });

        if (wallpapers.length === 0) {
            return NextResponse.json(
                { error: "No wallpaper found" },
                {
                    status: 404,
                    headers: {
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Methods": "GET, OPTIONS",
                    }
                }
            );
        }

        // Apply 90-minute Rotation Logic (Same as Main API)
        // If there are multiple wallpapers for the "Latest Day", we cycle them.
        let selectedWallpaper = wallpapers[0];

        if (wallpapers.length > 1 && wallpapers[0].releaseDate) {
            const topDate = new Date(wallpapers[0].releaseDate).toDateString();

            // Count how many belong to this same day
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
                const now = Date.now();
                const intervalMs = 1000 * 60 * 90; // 90 minutes
                const blockIndex = Math.floor(now / intervalMs);

                // Determine which index (0 to sameDayCount-1) should be active
                const activeIndex = blockIndex % sameDayCount;

                selectedWallpaper = wallpapers[activeIndex];
                console.log(`[Rotation] Selected index ${activeIndex} of ${sameDayCount} for today.`);
            }
        }

        return NextResponse.json(selectedWallpaper, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });
    } catch (error) {
        console.error("Error fetching today's wallpaper:", error);
        return NextResponse.json(
            { error: "Internal Server Error" },
            {
                status: 500,
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, OPTIONS",
                }
            }
        );
    }
}

export async function OPTIONS() {
    return NextResponse.json({}, {
        headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
    });
}
