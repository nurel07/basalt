import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

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

        return NextResponse.json(wallpaper, {
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
