import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
    const wallpaper = await prisma.wallpaper.findFirst({
        where: {
            releaseDate: {
                lte: new Date(),
            },
        },
        orderBy: [
            { releaseDate: "desc" },
            { createdAt: "desc" },
        ],
    });

    if (!wallpaper) {
        return NextResponse.json({ error: "No wallpaper found" }, { status: 404 });
    }

    return NextResponse.json(wallpaper);
}
