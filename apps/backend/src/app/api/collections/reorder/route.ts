import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function PUT(request: Request) {
    try {
        const body = await request.json();
        const { orderedIds } = body; // Array of strings

        if (!Array.isArray(orderedIds)) {
            return NextResponse.json({ error: "Invalid data" }, { status: 400 });
        }

        // Use transaction to update all
        await prisma.$transaction(
            orderedIds.map((id: string, index: number) =>
                prisma.mobileCollection.update({
                    where: { id },
                    data: { order: index },
                })
            )
        );

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Error reordering collections:", error);
        return NextResponse.json({ error: "Error reordering" }, { status: 500 });
    }
}
