import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = 'force-dynamic'; // Ensure this endpoint is not cached

// Simple Pseudo-Random Number Generator (Linear Congruential Generator)
class SeededRandom {
    private seed: number;

    constructor(seedStr: string) {
        this.seed = this.cyrb128(seedStr);
    }

    // String hashing function (cyrb128 mix) to get a numeric seed
    private cyrb128(str: string): number {
        let h1 = 1779033703, h2 = 3144134277,
            h3 = 1013904242, h4 = 2773480762;
        for (let i = 0, k; i < str.length; i++) {
            k = str.charCodeAt(i);
            h1 = h2 ^ Math.imul(h1 ^ k, 597399067);
            h2 = h3 ^ Math.imul(h2 ^ k, 2869860233);
            h3 = h4 ^ Math.imul(h3 ^ k, 951274213);
            h4 = h1 ^ Math.imul(h4 ^ k, 2716044179);
        }
        h1 = Math.imul(h3 ^ (h1 >>> 18), 597399067);
        h2 = Math.imul(h4 ^ (h2 >>> 22), 2869860233);
        h3 = Math.imul(h1 ^ (h3 >>> 17), 951274213);
        h4 = Math.imul(h2 ^ (h4 >>> 19), 2716044179);
        return (h1 ^ h2 ^ h3 ^ h4) >>> 0;
    }

    // Returns a pseudo-random number between 0 and 1
    next(): number {
        this.seed = (this.seed * 1664525 + 1013904223) % 4294967296;
        return this.seed / 4294967296;
    }

    // Helper: Random integer between 0 and max (exclusive)
    nextInt(max: number): number {
        return Math.floor(this.next() * max);
    }
}

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
            // Initialize Random Generator with Today's formatted date as seed
            // This ensures everyone gets the same "Random" wallpapers for the day
            const todayStr = new Date().toISOString().split('T')[0]; // "2024-05-20"
            const rng = new SeededRandom(todayStr);

            const numToFetch = Math.min(2, pastWallpapersCount);

            // Generate unique random indices using our seeded RNG
            const randomIndices: number[] = [];
            while (randomIndices.length < numToFetch) {
                const randIndex = rng.nextInt(pastWallpapersCount);
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
