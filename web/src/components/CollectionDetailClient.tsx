"use client";

import { useState } from "react";
import Link from "next/link";
import MasonryGrid from "@/components/MasonryGrid";
import AdminWallpaperItem from "@/components/AdminWallpaperItem";
import UploadModal, { MobileCollection, Wallpaper } from "@/components/UploadModal";
import UploadCell from "@/components/UploadCell";

interface CollectionDetailClientProps {
    collection: MobileCollection;
    wallpapers: Wallpaper[];
}

export default function CollectionDetailClient({ collection, wallpapers }: CollectionDetailClientProps) {
    // Modal State
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [activeWallpaper, setActiveWallpaper] = useState<Wallpaper | undefined>(undefined);
    const [modalMode, setModalMode] = useState<"UPLOAD" | "RESCHEDULE" | "EDIT">("UPLOAD");

    const handleEdit = (wallpaper: Wallpaper) => {
        setActiveWallpaper(wallpaper);
        setModalMode("EDIT");
        setIsModalOpen(true);
    };

    const handleCloseModal = () => {
        setIsModalOpen(false);
        setActiveWallpaper(undefined);
        setModalMode("UPLOAD");
    };

    return (
        <div className="p-8">
            {/* Header */}
            <div className="mb-8">
                <Link href="/admin" className="text-sm text-gray-500 hover:text-gray-900 mb-2 inline-block">
                    ← Back to Dashboard
                </Link>
                <div className="flex justify-between items-center">
                    <div>
                        <h1 className="text-3xl font-bold">{collection.name}</h1>
                        <p className="text-gray-500">Collection Gallery</p>
                    </div>
                    <button
                        onClick={() => {
                            setModalMode("UPLOAD");
                            setIsModalOpen(true);
                        }}
                        className="bg-pink-600 text-white px-6 py-2 rounded-lg hover:bg-pink-700 transition-colors font-medium flex items-center gap-2"
                    >
                        <span>➕</span> Upload to Collection
                    </button>
                </div>
            </div>

            {/* Content */}
            <MasonryGrid gap="gap-0 space-y-0">
                <div onClick={() => setIsModalOpen(true)}>
                    <UploadCell />
                </div>

                {wallpapers.map((wallpaper) => (
                    <AdminWallpaperItem
                        key={wallpaper.id}
                        wallpaper={wallpaper}
                        onEdit={handleEdit}
                    />
                ))}
                {wallpapers.length === 0 && (
                    <div className="col-span-full p-12 text-center text-gray-400 border-2 border-dashed border-gray-200 rounded-xl">
                        No wallpapers in this collection yet.
                    </div>
                )}
            </MasonryGrid>

            {/* Upload Modal */}
            <UploadModal
                isOpen={isModalOpen}
                onClose={handleCloseModal}
                wallpaper={activeWallpaper}
                mode={modalMode}
                file={null}
                previewUrl=""
                collections={[collection]} // Pass just this collection so it's available in dropdown if checks needed
                initialCollectionId={collection.id} // Pre-fill and lock to this collection (logic in Modal)
            />
        </div>
    );
}
