import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const channel = searchParams.get("channel");

    try {
        const where = channel ? { channel } : {};

        const wallpapers = await prisma.wallpaper.findMany({
            where,
            orderBy: [
                { releaseDate: "desc" },
                { createdAt: "desc" },
            ],
        });
        return NextResponse.json(wallpapers);
    } catch (error) {
        console.error("Error fetching wallpapers:", error);
        return NextResponse.json({ error: "Error fetching wallpapers" }, { status: 500 });
    }
}

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { url, name, description, externalUrl, channel, releaseDate } = body;

        const wallpaper = await prisma.wallpaper.create({
            data: {
                url,
                name,
                description,
                externalUrl,
                channel: channel || "HUMAN",
                releaseDate: new Date(releaseDate),
            },
        });

        return NextResponse.json(wallpaper);
    } catch (error) {
        console.error(error);
        return NextResponse.json({ error: "Error creating wallpaper" }, { status: 500 });
    }
}
