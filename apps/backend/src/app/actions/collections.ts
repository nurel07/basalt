"use server";

import { prisma } from "@/lib/prisma";
import { revalidatePath } from "next/cache";

export async function reorderWallpapers(updates: { id: string; order: number }[]) {
    try {
        await prisma.$transaction(async (tx) => {
            // 1. Update orders
            for (const update of updates) {
                await tx.wallpaper.update({
                    where: { id: update.id },
                    data: { collectionOrder: update.order },
                });
            }

            // 2. Check for new cover (index 0)
            const newCoverItem = updates.find(u => u.order === 0);
            if (newCoverItem) {
                const wallpaper = await tx.wallpaper.findUnique({
                    where: { id: newCoverItem.id },
                    select: { collectionId: true, url: true }
                });

                if (wallpaper && wallpaper.collectionId) {
                    await tx.mobileCollection.update({
                        where: { id: wallpaper.collectionId },
                        data: { coverImage: wallpaper.url }
                    });
                }
            }
        });
        revalidatePath("/admin/collections/[id]", "page");
        return { success: true };
    } catch (error) {
        console.error("Failed to reorder wallpapers:", error);
        return { success: false, error: "Failed to update order" };
    }
}
