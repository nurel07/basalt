import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

// Helper to inject Cloudinary optimization params
function optimizeUrl(url: string): string {
    const keyword = "/upload/";
    if (!url.includes(keyword)) return url;

    // w_1248: Max width 1248px
    // c_limit: Only downscale, never upscale
    // q_auto: Automatic quality (best visual quality for lowest size)
    // f_auto: Automatic format (WebP/AVIF if supported)
    const params = "w_1248,c_limit,q_auto,f_auto";

    // Insert params after /upload/
    return url.replace(keyword, `${keyword}${params}/`);
}

export async function GET(request: Request) {
    try {
        // Fetch the latest "Fine Art" (HUMAN channel) wallpaper released on or before today
        const wallpaper = await prisma.wallpaper.findFirst({
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
        });

        if (!wallpaper) {
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

        // Return optimized payload
        const responsePayload = {
            ...wallpaper,
            websiteUrl: optimizeUrl(wallpaper.url),
        };

        return NextResponse.json(responsePayload, {
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
