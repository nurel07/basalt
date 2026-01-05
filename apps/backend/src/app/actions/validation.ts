"use server";

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export async function checkDuplicateTitle(title: string, excludeId?: string) {
    if (!title) return false;

    try {
        const count = await prisma.wallpaper.count({
            where: {
                name: {
                    equals: title,
                    mode: 'insensitive' // Case-insensitive check
                },
                channel: "HUMAN",
                ...(excludeId ? { id: { not: excludeId } } : {})
            }
        });

        return count > 0;
    } catch (error) {
        console.error("Duplicate check failed:", error);
        return false;
    }
}
