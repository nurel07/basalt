import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
    try {
        const collections = await prisma.mobileCollection.findMany({
            include: {
                _count: {
                    select: { wallpapers: true },
                },
            },
            orderBy: { name: "asc" },
        });

        // Add count to the response explicitly if needed or use client side
        return NextResponse.json(collections);
    } catch (error) {
        console.error("Error fetching collections:", error);
        return NextResponse.json(
            { error: "Error fetching collections" },
            { status: 500 }
        );
    }
}

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { name, slug, description, coverImage } = body;

        if (!name || !slug || !coverImage) {
            return NextResponse.json(
                { error: "Missing required fields" },
                { status: 400 }
            );
        }

        const newCollection = await prisma.mobileCollection.create({
            data: {
                name,
                slug,
                description,
                coverImage,
                isPublished: true, // Default to published for now
            },
        });

        return NextResponse.json(newCollection);
    } catch (error) {
        console.error("Error creating collection:", error);
        return NextResponse.json(
            { error: "Error creating collection" },
            { status: 500 }
        );
    }
}
