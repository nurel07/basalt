import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const id = (await params).id;

        const collection = await prisma.mobileCollection.findUnique({
            where: { id },
            include: {
                wallpapers: {
                    orderBy: { createdAt: "desc" },
                },
            },
        });

        if (!collection) {
            return NextResponse.json(
                { error: "Collection not found" },
                { status: 404 }
            );
        }

        return NextResponse.json(collection);
    } catch (error) {
        console.error("Error fetching collection:", error);
        return NextResponse.json(
            { error: "Error fetching collection" },
            { status: 500 }
        );
    }
}

export async function PUT(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const id = (await params).id;
        const body = await request.json();
        const { name, slug, description, coverImage } = body;

        const updatedCollection = await prisma.mobileCollection.update({
            where: { id },
            data: {
                name,
                slug,
                description,
                coverImage,
            },
        });

        return NextResponse.json(updatedCollection);
    } catch (error) {
        console.error("Error updating collection:", error);
        return NextResponse.json(
            { error: "Error updating collection" },
            { status: 500 }
        );
    }
}

export async function DELETE(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const id = (await params).id;

        await prisma.$transaction(async (tx) => {
            // Delete all wallpapers in this collection first
            await tx.wallpaper.deleteMany({
                where: { collectionId: id },
            });

            // Then delete the collection
            await tx.mobileCollection.delete({
                where: { id },
            });
        });

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Error deleting collection:", error);
        return NextResponse.json(
            { error: "Error deleting collection" },
            { status: 500 }
        );
    }
}
