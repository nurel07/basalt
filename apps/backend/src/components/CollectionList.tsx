"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { MobileCollection } from "./UploadModal";
import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors, DragEndEvent } from "@dnd-kit/core";
import { arrayMove, SortableContext, sortableKeyboardCoordinates, useSortable, rectSortingStrategy } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import CreateCollectionModal from "./CreateCollectionModal";

interface CollectionListProps {
    initialCollections: MobileCollection[];
}

export default function CollectionList({ initialCollections }: CollectionListProps) {
    const [collections, setCollections] = useState(initialCollections);
    const [isCollectionModalOpen, setIsCollectionModalOpen] = useState(false);

    useEffect(() => {
        setCollections(initialCollections);
    }, [initialCollections]);

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

        if (active.id !== over?.id) {
            setCollections((items) => {
                const oldIndex = items.findIndex((item) => item.id === active.id);
                const newIndex = items.findIndex((item) => item.id === over!.id);
                const newItems = arrayMove(items, oldIndex, newIndex);

                updateOrder(newItems);

                return newItems;
            });
        }
    };

    const updateOrder = async (items: MobileCollection[]) => {
        const orderedIds = items.map(c => c.id);
        try {
            await fetch("/api/collections/reorder", {
                method: "PUT",
                body: JSON.stringify({ orderedIds }),
            });
        } catch (error) {
            console.error("Failed to reorder collections:", error);
        }
    };

    return (
        <>
            <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleDragEnd}
            >
                <SortableContext
                    items={collections.map(c => c.id)}
                    strategy={rectSortingStrategy}
                >
                    <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                        {/* Create Collection Card */}
                        <div
                            onClick={() => setIsCollectionModalOpen(true)}
                            className="aspect-[4/3] bg-gray-50 dark:bg-gray-800 border-2 border-dashed border-gray-300 rounded-xl flex flex-col items-center justify-center p-6 text-center cursor-pointer hover:border-pink-500 hover:text-pink-600 transition-colors group"
                        >
                            <span className="text-3xl mb-2 group-hover:scale-110 transition-transform">➕</span>
                            <span className="font-semibold">New Collection</span>
                        </div>

                        {collections.map((collection) => (
                            <SortableCollectionItem key={collection.id} collection={collection} />
                        ))}
                    </div>
                </SortableContext>
            </DndContext>

            <CreateCollectionModal
                isOpen={isCollectionModalOpen}
                onClose={() => setIsCollectionModalOpen(false)}
            />
        </>
    );
}

function SortableCollectionItem({ collection }: { collection: MobileCollection }) {
    const {
        attributes,
        listeners,
        setNodeRef,
        transform,
        transition,
    } = useSortable({ id: collection.id });

    const style = {
        transform: CSS.Transform.toString(transform),
        transition,
    };

    return (
        <div ref={setNodeRef} style={style} {...attributes} {...listeners} className="touch-none h-full">
            <Link href={`/admin/collections/${collection.id}`} className="aspect-[4/3] bg-gray-200 rounded-xl relative overflow-hidden group cursor-pointer hover:shadow-lg transition-all block h-full">
                {collection.coverImage && (
                    <img src={collection.coverImage} className="absolute inset-0 w-full h-full object-cover transition-transform group-hover:scale-105" />
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent flex items-end p-4">
                    <div className="flex justify-between w-full items-end">
                        <h3 className="text-white font-bold text-lg max-w-[70%] truncate">{collection.name}</h3>
                        {/* Badge */}
                        {collection.channel === "AI" ? (
                            <span className="bg-purple-600/90 text-white text-[10px] uppercase font-bold px-2 py-0.5 rounded-full backdrop-blur-sm">AI</span>
                        ) : (
                            <span className="bg-blue-600/90 text-white text-[10px] uppercase font-bold px-2 py-0.5 rounded-full backdrop-blur-sm">Human</span>
                        )}
                    </div>
                </div>
            </Link>
        </div>
    );
}
