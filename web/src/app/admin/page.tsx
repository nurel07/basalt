import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { format } from "date-fns";

export const dynamic = "force-dynamic";

import { auth } from "@/auth";
import { redirect } from "next/navigation";
import AdminWallpaperItem from "@/components/AdminWallpaperItem";

export default async function AdminDashboard() {
    const session = await auth();
    if (!session) {
        redirect("/login");
    }
    const wallpapers = await prisma.wallpaper.findMany({
        orderBy: { releaseDate: "desc" },
    });

    return (
        <div className="p-8">
            <div className="flex justify-between items-center mb-8">
                <h1 className="text-3xl font-bold">Admin Dashboard</h1>
                <Link
                    href="/admin/upload"
                    className="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"
                >
                    Upload New Wallpaper
                </Link>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {wallpapers.map((wallpaper) => (
                    <AdminWallpaperItem key={wallpaper.id} wallpaper={wallpaper} />
                ))}
            </div>
        </div>
    );
}
