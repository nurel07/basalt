"use client";

import { useState } from "react";
import Link from "next/link";
import MasonryGrid from "./MasonryGrid";
import AdminWallpaperItem from "./AdminWallpaperItem";
import UploadCell from "./UploadCell";
import UploadModal, { Wallpaper } from "./UploadModal";


import CreateCollectionModal from "./CreateCollectionModal";
import { MobileCollection } from "./UploadModal";

interface AdminDashboardTabsProps {
    pastWallpapers: Wallpaper[];
    futureWallpapers: Wallpaper[];
    collections: MobileCollection[];
}

export default function AdminDashboardTabs({
    pastWallpapers,
    futureWallpapers,
    collections,
}: AdminDashboardTabsProps) {
    const [area, setArea] = useState<"DESKTOP" | "MOBILE">("DESKTOP");
    const [activeTab, setActiveTab] = useState<"future" | "past">("future");
    const [channelFilter, setChannelFilter] = useState<"ALL" | "HUMAN" | "AI">("ALL");

    // Modal state
    const [activeWallpaper, setActiveWallpaper] = useState<Wallpaper | undefined>(undefined);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [modalMode, setModalMode] = useState<"UPLOAD" | "RESCHEDULE" | "EDIT">("UPLOAD");

    // New Collection Modal State
    const [isCollectionModalOpen, setIsCollectionModalOpen] = useState(false);

    const filterWallpapers = (list: Wallpaper[]) => {
        if (channelFilter === "ALL") return list;
        return list.filter((w) => (w.channel || "HUMAN") === channelFilter);
    };

    const filteredFuture = filterWallpapers(futureWallpapers);
    const filteredPast = filterWallpapers(pastWallpapers);

    const handleReschedule = (wallpaper: Wallpaper) => {
        setActiveWallpaper(wallpaper);
        setModalMode("RESCHEDULE");
        setIsModalOpen(true);
    };

    const handleEdit = (wallpaper: Wallpaper) => {
        setActiveWallpaper(wallpaper);
        setModalMode("EDIT");
        setIsModalOpen(true);
    };

    const handleCloseModal = () => {
        setIsModalOpen(false);
        setActiveWallpaper(undefined);
        setModalMode("UPLOAD"); // Reset to default
    };

    return (
        <div>
            {/* Tabs Header */}
            {/* Header: Tabs + Filters */}
            {/* Header: Tabs + Filters */}
            {/* Header: Tabs + Filters */}
            <div className="flex flex-col gap-6 mb-8 border-b border-gray-200 pb-6">

                {/* 1. Top Level Area Toggle */}
                <div className="flex self-start bg-gray-100 p-1 rounded-lg">
                    <button
                        onClick={() => setArea("DESKTOP")}
                        className={`flex items-center gap-2 px-6 py-2 rounded-md font-medium transition-all ${area === "DESKTOP" ? "bg-white text-blue-600 shadow-sm" : "text-gray-500 hover:text-gray-900"
                            }`}
                    >
                        🖥️ Desktop (Daily)
                    </button>
                    <button
                        onClick={() => setArea("MOBILE")}
                        className={`flex items-center gap-2 px-6 py-2 rounded-md font-medium transition-all ${area === "MOBILE" ? "bg-white text-pink-600 shadow-sm" : "text-gray-500 hover:text-gray-900"
                            }`}
                    >
                        📱 Mobile (Collections)
                    </button>
                </div>

                {/* 2. Sub-Filters (Only for Desktop) */}
                {area === "DESKTOP" && (
                    <div className="flex flex-row items-center gap-6 overflow-x-auto">
                        <div className="flex bg-gray-100 rounded-lg p-1.5 text-sm font-medium shrink-0">
                            <button
                                onClick={() => setActiveTab("future")}
                                className={`px-5 py-2 rounded-md transition-all ${activeTab === "future"
                                    ? "bg-white text-black shadow-sm"
                                    : "text-gray-500 hover:text-gray-700"
                                    }`}
                            >
                                Future <span className="opacity-60 ml-1">({filteredFuture.length})</span>
                            </button>
                            <button
                                onClick={() => setActiveTab("past")}
                                className={`px-5 py-2 rounded-md transition-all ${activeTab === "past"
                                    ? "bg-white text-black shadow-sm"
                                    : "text-gray-500 hover:text-gray-700"
                                    }`}
                            >
                                Past <span className="opacity-60 ml-1">({filteredPast.length})</span>
                            </button>
                        </div>

                        <div className="flex bg-gray-100 rounded-lg p-1.5 text-sm font-medium shrink-0">
                            {[
                                { id: "ALL", label: "All" },
                                { id: "HUMAN", label: "Human" },
                                { id: "AI", label: "AI" }
                            ].map((filter) => (
                                <button
                                    key={filter.id}
                                    onClick={() => setChannelFilter(filter.id as "ALL" | "HUMAN" | "AI")}
                                    className={`px-5 py-2 rounded-md transition-all ${channelFilter === filter.id
                                        ? "bg-white text-black shadow-sm"
                                        : "text-gray-500 hover:text-gray-700"
                                        }`}
                                >
                                    {filter.label}
                                </button>
                            ))}
                        </div>
                    </div>
                )}
            </div>

            {/* Content */}
            <div className="min-h-[500px]">
                {area === "MOBILE" ? (
                    <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                        {/* Create Collection Card */}
                        <div
                            onClick={() => setIsCollectionModalOpen(true)}
                            className="aspect-[4/3] bg-gray-50 dark:bg-gray-800 border-2 border-dashed border-gray-300 rounded-xl flex flex-col items-center justify-center p-6 text-center cursor-pointer hover:border-pink-500 hover:text-pink-600 transition-colors group"
                        >
                            <span className="text-3xl mb-2 group-hover:scale-110 transition-transform">➕</span>
                            <span className="font-semibold">New Collection</span>
                        </div>

                        {collections.map(collection => (
                            <Link href={`/admin/collections/${collection.id}`} key={collection.id} className="aspect-[4/3] bg-gray-200 rounded-xl relative overflow-hidden group cursor-pointer hover:shadow-lg transition-all block">
                                {/* Only Name for now since we don't have Cover Image in the minimal type yet */}
                                {collection.coverImage && (
                                    <img src={collection.coverImage} className="absolute inset-0 w-full h-full object-cover transition-transform group-hover:scale-105" />
                                )}
                                <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent flex items-end p-4">
                                    <h3 className="text-white font-bold text-lg">{collection.name}</h3>
                                </div>
                            </Link>
                        ))}

                        {/* Only show UploadCell if in Mobile Mode to add to collections? 
                            Actually, UploadCell is for adding wallpapers. 
                            If we are in "Collections View", we click a collection to see wallpapers. 
                            For now, let's keep UploadCell available but strictly for "Mobile" Type uploads if needed. 
                            But maybe hide it here?
                        */}
                    </div>
                ) : activeTab === "future" ? (
                    <MasonryGrid gap="gap-0 space-y-0">
                        {/* Upload Trigger always visible in Future? Or both? Usually convenient in Future/Active tab */}
                        <UploadCell />
                        {filteredFuture.map((wallpaper) => (
                            <AdminWallpaperItem
                                key={wallpaper.id}
                                wallpaper={wallpaper}
                                onEdit={handleEdit}
                            />
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
                                onEdit={handleEdit}
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

            {/* Generic Modal */}
            <UploadModal
                isOpen={isModalOpen}
                onClose={handleCloseModal}
                wallpaper={activeWallpaper}
                mode={modalMode}
                file={null}
                previewUrl=""
                collections={collections}
            />
            {/* Collection Creation Modal */}
            <CreateCollectionModal
                isOpen={isCollectionModalOpen}
                onClose={() => setIsCollectionModalOpen(false)}
            />
        </div>
    );
}
