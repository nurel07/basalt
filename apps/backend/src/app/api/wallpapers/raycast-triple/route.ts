import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = 'force-dynamic'; // Ensure this endpoint is not cached

// Helper to inject Cloudinary optimization params
function optimizeUrl(url: string, width: number = 1248): string {
    const keyword = "/upload/";
    if (!url.includes(keyword)) return url;

    // c_limit: Only downscale, never upscale
    // q_auto: Automatic quality (best visual quality for lowest size)
    // f_auto: Automatic format (WebP/AVIF if supported)
    const params = `w_${width},c_limit,q_auto,f_auto`;

    return url.replace(keyword, `${keyword}${params}/`);
}

export async function GET() {
    try {
        // 1. Fetch today's wallpaper (latest released HUMAN channel wallpaper)
        const todayWallpaper = await prisma.wallpaper.findFirst({
            where: {
                releaseDate: {
                    lte: new Date(),
                },
                channel: "HUMAN",
                type: "DESKTOP",
            },
            orderBy: [
                { releaseDate: "desc" },
                { createdAt: "desc" },
            ],
        });

        if (!todayWallpaper) {
            return NextResponse.json(
                { error: "No today's wallpaper found" },
                { status: 404 }
            );
        }

        // 2. Fetch 2 random past wallpapers (excluding today's)
        const pastWallpapersCount = await prisma.wallpaper.count({
            where: {
                releaseDate: {
                    lte: new Date(),
                },
                channel: "HUMAN",
                type: "DESKTOP",
                id: {
                    not: todayWallpaper.id,
                },
            },
        });

        let randomWallpapers: typeof todayWallpaper[] = [];

        if (pastWallpapersCount > 0) {
            // Get 2 random wallpapers using skip with random offset
            // If we have less than 2, we'll just get what we have
            const numToFetch = Math.min(2, pastWallpapersCount);

            // Generate unique random indices
            const randomIndices: number[] = [];
            while (randomIndices.length < numToFetch) {
                const randIndex = Math.floor(Math.random() * pastWallpapersCount);
                if (!randomIndices.includes(randIndex)) {
                    randomIndices.push(randIndex);
                }
            }

            // Fetch each random wallpaper
            for (const skipIndex of randomIndices) {
                const wallpaper = await prisma.wallpaper.findFirst({
                    where: {
                        releaseDate: {
                            lte: new Date(),
                        },
                        channel: "HUMAN",
                        type: "DESKTOP",
                        id: {
                            not: todayWallpaper.id,
                        },
                    },
                    skip: skipIndex,
                    orderBy: [
                        { releaseDate: "desc" },
                        { createdAt: "desc" },
                    ],
                });

                if (wallpaper) {
                    randomWallpapers.push(wallpaper);
                }
            }
        }

        // 3. Build response with optimized URLs (matching today endpoint format)
        const formatWallpaper = (wallpaper: typeof todayWallpaper) => ({
            ...wallpaper,
            websiteUrl: optimizeUrl(wallpaper.url, 1248),
            thumbnailUrl: optimizeUrl(wallpaper.url, 400),
        });

        const response = {
            today: formatWallpaper(todayWallpaper),
            random: randomWallpapers.map(formatWallpaper),
        };

        return NextResponse.json(response, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });

    } catch (error) {
        console.error("Error fetching raycast triple:", error);
        return NextResponse.json(
            { error: "Internal Server Error" },
            { status: 500 }
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
