import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import EditWallpaperForm from "./EditWallpaperForm";

export default async function EditWallpaperPage({
    params,
}: {
    params: Promise<{ id: string }>;
}) {
    const { id } = await params;
    const wallpaper = await prisma.wallpaper.findUnique({
        where: { id },
    });

    if (!wallpaper) {
        notFound();
    }

    return (
        <div className="p-8 max-w-2xl mx-auto">
            <h1 className="text-3xl font-bold mb-8">Edit Wallpaper</h1>
            <EditWallpaperForm wallpaper={wallpaper} />
        </div>
    );
}
