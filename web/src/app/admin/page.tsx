import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { format } from "date-fns";

export const dynamic = "force-dynamic";

import { auth } from "@/auth";
import { redirect } from "next/navigation";
import AdminWallpaperItem from "@/components/AdminWallpaperItem";
import SignOutButton from "@/components/SignOutButton";
import MasonryGrid from "@/components/MasonryGrid";
import UploadCell from "@/components/UploadCell";

export default async function AdminDashboard() {
    const session = await auth();
    console.log("Admin Dashboard Session:", JSON.stringify(session, null, 2));
    if (!session) {
        redirect("/login");
    }
    const wallpapers = await prisma.wallpaper.findMany({
        orderBy: { releaseDate: "asc" },
    });

    return (
        <div className="p-8">
            {/* Header Area */}
            <div className="flex justify-between items-start mb-8">
                {/* Left side empty or for other controls if needed */}
                <div className="flex-1"></div>

                {/* Right side: Title and Controls */}
                <div className="flex flex-col items-end gap-4">
                    <div className="flex items-center gap-4">
                        <div className="text-right">
                            <h1 className="text-2xl font-bold">Admin Dashboard</h1>
                            <p className="text-xs text-gray-500">Logged in as: {session?.user?.name}</p>
                        </div>
                        <SignOutButton />
                    </div>
                </div>
            </div>

            <MasonryGrid gap="gap-0 space-y-0">
                {/* First cell is always the Upload trigger */}
                <UploadCell />

                {/* Remaining cells are wallpapers */}
                {wallpapers.map((wallpaper) => (
                    <AdminWallpaperItem key={wallpaper.id} wallpaper={wallpaper} />
                ))}
            </MasonryGrid>

            <div className="mt-12 text-center text-gray-500 text-xs">
                Admin Dashboard v2.0 (Masonry Layout)
            </div>
        </div>
    );
}
