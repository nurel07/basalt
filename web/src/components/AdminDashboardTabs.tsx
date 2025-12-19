"use client";

import { useState } from "react";
import MasonryGrid from "./MasonryGrid";
import AdminWallpaperItem from "./AdminWallpaperItem";
import UploadCell from "./UploadCell";
import UploadModal, { Wallpaper } from "./UploadModal";



interface AdminDashboardTabsProps {
    pastWallpapers: Wallpaper[];
    futureWallpapers: Wallpaper[];
}

export default function AdminDashboardTabs({
    pastWallpapers,
    futureWallpapers,
}: AdminDashboardTabsProps) {
    const [activeTab, setActiveTab] = useState<"future" | "past">(
        futureWallpapers.length > 0 ? "future" : "past"
    );
    const [channelFilter, setChannelFilter] = useState<"ALL" | "HUMAN" | "AI">("ALL");

    // Reschedule state
    const [rescheduleWallpaper, setRescheduleWallpaper] = useState<Wallpaper | undefined>(undefined);
    const [isRescheduleModalOpen, setIsRescheduleModalOpen] = useState(false);

    const filterWallpapers = (list: Wallpaper[]) => {
        if (channelFilter === "ALL") return list;
        return list.filter((w) => (w.channel || "HUMAN") === channelFilter);
    };

    const filteredFuture = filterWallpapers(futureWallpapers);
    const filteredPast = filterWallpapers(pastWallpapers);

    const handleReschedule = (wallpaper: Wallpaper) => {
        setRescheduleWallpaper(wallpaper);
        setIsRescheduleModalOpen(true);
    };

    return (
        <div>
            {/* Tabs Header */}
            {/* Header: Tabs + Filters */}
            <div className="flex flex-col md:flex-row justify-between items-end border-b border-gray-200 mb-6 pb-0">
                <div className="flex">
                    <button
                        onClick={() => setActiveTab("future")}
                        className={`px-6 py-3 font-medium text-sm transition-colors border-b-2 ${activeTab === "future"
                            ? "border-black text-black"
                            : "border-transparent text-gray-400 hover:text-gray-600"
                            }`}
                    >
                        Future ({filteredFuture.length})
                    </button>
                    <button
                        onClick={() => setActiveTab("past")}
                        className={`px-6 py-3 font-medium text-sm transition-colors border-b-2 ${activeTab === "past"
                            ? "border-black text-black"
                            : "border-transparent text-gray-400 hover:text-gray-600"
                            }`}
                    >
                        Past ({filteredPast.length})
                    </button>
                </div>

                <div className="flex bg-gray-100 rounded-lg p-1 mb-2 md:mb-2 text-xs font-medium">
                    {(["ALL", "HUMAN", "AI"] as const).map((filter) => (
                        <button
                            key={filter}
                            onClick={() => setChannelFilter(filter)}
                            className={`px-4 py-1.5 rounded-md transition-all ${channelFilter === filter
                                ? "bg-white text-black shadow-sm"
                                : "text-gray-500 hover:text-gray-700"
                                }`}
                        >
                            {filter}
                        </button>
                    ))}
                </div>
            </div>

            {/* Content */}
            <div className="min-h-[500px]">
                {activeTab === "future" ? (
                    <MasonryGrid gap="gap-0 space-y-0">
                        {/* Upload Trigger always visible in Future? Or both? Usually convenient in Future/Active tab */}
                        <UploadCell />
                        {filteredFuture.map((wallpaper) => (
                            <AdminWallpaperItem key={wallpaper.id} wallpaper={wallpaper} />
                        ))}
                        {filteredFuture.length === 0 && (
                            <div className="col-span-full p-8 text-center text-gray-400">
                                No scheduled wallpapers.
                            </div>
                        )}
                    </MasonryGrid>
                ) : (
                    <MasonryGrid gap="gap-0 space-y-0">
                        {/* We can show UploadCell in Past too if user wants to back-fill */}
                        <UploadCell />
                        {filteredPast.map((wallpaper) => (
                            <AdminWallpaperItem
                                key={wallpaper.id}
                                wallpaper={wallpaper}
                                onReschedule={handleReschedule}
                            />
                        ))}
                        {filteredPast.length === 0 && (
                            <div className="col-span-full p-8 text-center text-gray-400">
                                No past wallpapers.
                            </div>
                        )}
                    </MasonryGrid>
                )}
            </div>

            {/* Reschedule Modal */}
            <UploadModal
                isOpen={isRescheduleModalOpen}
                onClose={() => {
                    setIsRescheduleModalOpen(false);
                    setRescheduleWallpaper(undefined);
                }}
                wallpaper={rescheduleWallpaper}
                mode="RESCHEDULE"
                file={null}
                previewUrl=""
            />
        </div>
    );
}
