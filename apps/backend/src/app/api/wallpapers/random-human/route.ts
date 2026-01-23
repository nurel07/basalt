import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = 'force-dynamic'; // Ensure this endpoint is not cached

// Helper to inject Cloudinary optimization params
function optimizeUrl(url: string, width: number = 2560): string {
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
        const where: any = {
            channel: "HUMAN",
            type: "DESKTOP",
            releaseDate: {
                lte: new Date(),
            },
        };

        // 1. Get Count
        const count = await prisma.wallpaper.count({ where });

        if (count === 0) {
            return NextResponse.json({ error: "No human wallpapers found" }, { status: 404 });
        }

        // 2. Random Skip
        const skip = Math.floor(Math.random() * count);

        // 3. Fetch One
        const randomWallpaper = await prisma.wallpaper.findFirst({
            where,
            skip,
            orderBy: [
                { releaseDate: "desc" },
                { createdAt: "desc" },
            ],
        });

        if (!randomWallpaper) {
            return NextResponse.json({ error: "Failed to fetch random human wallpaper" }, { status: 404 });
        }

        // 4. Build response with optimized URLs
        const response = {
            ...randomWallpaper,
            websiteUrl: optimizeUrl(randomWallpaper.url, 2560),
            thumbnailUrl: optimizeUrl(randomWallpaper.url, 600),
        };

        return NextResponse.json(response, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });

    } catch (error) {
        console.error("Error fetching random human wallpaper:", error);
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
