"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import MasonryGrid from "@/components/MasonryGrid";
import AdminWallpaperItem from "@/components/AdminWallpaperItem";
import UploadModal, { MobileCollection, Wallpaper } from "@/components/UploadModal";
import UploadCell from "@/components/UploadCell";
import CreateCollectionModal from "@/components/CreateCollectionModal";

interface CollectionDetailClientProps {
    collection: MobileCollection;
    wallpapers: Wallpaper[];
}

import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors, DragEndEvent } from '@dnd-kit/core';
import { arrayMove, SortableContext, sortableKeyboardCoordinates, rectSortingStrategy, useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { reorderWallpapers } from "@/app/actions/collections";

// Sortable Item Component
function SortableWallpaperItem({ wallpaper, index, onEdit }: { wallpaper: Wallpaper; index: number; onEdit: (w: Wallpaper) => void }) {
    const {
        attributes,
        listeners,
        setNodeRef,
        transform,
        transition,
        isDragging
    } = useSortable({ id: wallpaper.id });

    const style = {
        transform: CSS.Transform.toString(transform),
        transition,
        zIndex: isDragging ? 10 : 1,
        opacity: isDragging ? 0.5 : 1,
    };

    return (
        <div ref={setNodeRef} style={style} {...attributes} {...listeners} className="relative group">
            <div className="absolute top-2 left-2 z-20 bg-black/50 text-white text-xs px-2 py-1 rounded backdrop-blur-sm pointer-events-none">
                #{index}
            </div>
            <AdminWallpaperItem
                wallpaper={wallpaper}
                onEdit={onEdit}
            />
        </div>
    );
}

export default function CollectionDetailClient({ collection, wallpapers }: CollectionDetailClientProps) {
    // Modal State
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isCollectionModalOpen, setIsCollectionModalOpen] = useState(false);
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

    // Ordering State
    const [items, setItems] = useState(wallpapers);

    // Sync state with props when router refreshes (e.g. after upload/delete)
    useEffect(() => {
        setItems(wallpapers);
    }, [wallpapers]);

    const sensors = useSensors(
        useSensor(PointerSensor, {
            activationConstraint: {
                distance: 8,
            },
        }),
        useSensor(KeyboardSensor, {
            coordinateGetter: sortableKeyboardCoordinates,
        })
    );

    const handleDragEnd = async (event: DragEndEvent) => {
        const { active, over } = event;

        if (over && active.id !== over.id) {
            const oldIndex = items.findIndex((item) => item.id === active.id);
            const newIndex = items.findIndex((item) => item.id === over.id);

            const newItems = arrayMove(items, oldIndex, newIndex);
            setItems(newItems);

            // Calculate new orders based on index
            const updates = newItems.map((item, index) => ({
                id: item.id,
                order: index
            }));

            // Call server action
            await reorderWallpapers(updates);
        }
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
                        <div className="flex items-center gap-3">
                            <h1 className="text-3xl font-bold">{collection.name}</h1>
                            <button
                                onClick={() => setIsCollectionModalOpen(true)}
                                className="text-gray-400 hover:text-blue-500 transition-colors"
                                title="Edit Collection Details"
                            >
                                ✏️
                            </button>
                        </div>
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
            {/* Content */}
            <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleDragEnd}
            >
                <SortableContext
                    items={items.map(w => w.id)}
                    strategy={rectSortingStrategy}
                >
                    <MasonryGrid gap="gap-4" variant="dense" className="grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
                        <div className="col-span-1">
                            <UploadCell initialCollectionId={collection.id} className="aspect-[9/16]" />
                        </div>

                        {items.map((wallpaper, index) => (
                            <SortableWallpaperItem
                                key={wallpaper.id}
                                wallpaper={wallpaper}
                                index={index}
                                onEdit={handleEdit}
                            />
                        ))}
                    </MasonryGrid>
                </SortableContext>
            </DndContext>

            {items.length === 0 && (
                <div className="p-12 text-center text-gray-400 border-2 border-dashed border-gray-200 rounded-xl mt-8">
                    No wallpapers in this collection yet.
                </div>
            )}

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

            {/* Edit Collection Modal */}
            <CreateCollectionModal
                isOpen={isCollectionModalOpen}
                onClose={() => setIsCollectionModalOpen(false)}
                initialData={collection}
            />
        </div>
    );
}
