"use server";

import { prisma } from "@/lib/prisma";
import { revalidatePath } from "next/cache";

export async function reorderWallpapers(updates: { id: string; order: number }[]) {
    try {
        await prisma.$transaction(
            updates.map((update) =>
                prisma.wallpaper.update({
                    where: { id: update.id },
                    data: { collectionOrder: update.order },
                })
            )
        );
        revalidatePath("/admin/collections/[id]", "page");
        return { success: true };
    } catch (error) {
        console.error("Failed to reorder wallpapers:", error);
        return { success: false, error: "Failed to update order" };
    }
}
