import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function DELETE(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id } = await params;
    await prisma.wallpaper.delete({
        where: { id },
    });
    return NextResponse.json({ success: true });
}

export async function PUT(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id } = await params;
    const body = await request.json();
    const { name, description, externalUrl, channel, releaseDate, artist, creationDate, genre, movement, dominantColors, tags } = body;

    const wallpaper = await prisma.wallpaper.update({
        where: { id },
        data: {
            name,
            description,
            externalUrl,
            channel,
            releaseDate: new Date(releaseDate),
            artist,
            creationDate,
            genre,
            movement,
            dominantColors,
            tags,
        },
    });
    return NextResponse.json(wallpaper);
}
