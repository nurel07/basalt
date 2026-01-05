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
import AdminDashboardTabs from "@/components/AdminDashboardTabs";

export default async function AdminDashboard() {
    const session = await auth();
    console.log("Admin Dashboard Session:", JSON.stringify(session, null, 2));
    if (!session) {
        redirect("/login");
    }

    const now = new Date();

    // Fetch Past and Future in parallel, plus Collections
    const [pastWallpapers, futureWallpapers, collections] = await Promise.all([
        prisma.wallpaper.findMany({
            where: {
                releaseDate: { lte: now },
                type: "DESKTOP",
            },
            orderBy: { releaseDate: "desc" }, // Past: Newest (closest to today) first
        }),
        prisma.wallpaper.findMany({
            where: {
                releaseDate: { gt: now },
                type: "DESKTOP",
            },
            orderBy: { releaseDate: "asc" }, // Future: Earliest (closest to today) first
        }),
        prisma.mobileCollection.findMany({
            orderBy: { name: "asc" },
        }),
    ]);

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

            {/* Smart Tabs Interface */}
            <AdminDashboardTabs
                pastWallpapers={pastWallpapers}
                futureWallpapers={futureWallpapers}
                collections={collections}
            />

            <div className="mt-12 text-center text-gray-500 text-xs">
                Basalt Admin v2.1
            </div>
        </div>
    );
}
