"use client";

import { format } from "date-fns";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Wallpaper } from "./UploadModal";
import { getOptimizedUrl } from "@/lib/cloudinary";
import { Link as LinkIcon, Check } from "lucide-react";
import { useState } from "react";



interface AdminWallpaperItemProps {
    wallpaper: Wallpaper;
    onReschedule?: (wallpaper: Wallpaper) => void;
    onEdit?: (wallpaper: Wallpaper) => void;
}

export default function AdminWallpaperItem({ wallpaper, onReschedule, onEdit }: AdminWallpaperItemProps) {
    const router = useRouter();
    const [copied, setCopied] = useState(false);

    const handleDelete = async () => {
        if (!confirm("Are you sure you want to delete this wallpaper?")) return;

        const res = await fetch(`/api/wallpapers/${wallpaper.id}`, {
            method: "DELETE",
        });

        if (res.ok) {
            router.refresh();
        } else {
            alert("Failed to delete wallpaper");
        }
    };

    const handleCopyLink = async () => {
        const url = `https://basalt.yevgenglukhov.com/art/${wallpaper.id}`;
        try {
            await navigator.clipboard.writeText(url);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch (err) {
            console.error("Failed to copy link:", err);
            alert("Failed to copy link");
        }
    };


    return (
        <div className="group relative">
            <img
                src={getOptimizedUrl(wallpaper.url, 600)}
                alt={wallpaper.name || wallpaper.description || "Wallpaper"}
                className="w-full h-auto object-cover block rounded-lg"
                loading="lazy"
            />

            {/* Overlay with buttons, visible only on hover */}
            <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex flex-col justify-between p-4 rounded-lg">
                <div className="flex justify-end gap-2 flex-wrap">
                    <button
                        onClick={handleCopyLink}
                        className="bg-white/90 text-black px-3 py-1 rounded text-sm font-medium hover:bg-white flex items-center gap-1 min-w-[32px] justify-center"
                        title="Copy public link"
                    >
                        {copied ? <Check className="w-4 h-4 text-green-600" /> : <LinkIcon className="w-4 h-4" />}
                    </button>
                    {onReschedule && (
                        <button
                            onClick={() => onReschedule(wallpaper)}
                            className="bg-blue-500/90 text-white px-3 py-1 rounded text-sm font-medium hover:bg-blue-600"
                        >
                            Reschedule
                        </button>
                    )}
                    {onEdit ? (
                        <button
                            onClick={() => onEdit(wallpaper)}
                            className="bg-white/90 text-black px-3 py-1 rounded text-sm font-medium hover:bg-white"
                        >
                            Edit
                        </button>
                    ) : (
                        <Link
                            href={`/admin/wallpapers/${wallpaper.id}/edit`}
                            className="bg-white/90 text-black px-3 py-1 rounded text-sm font-medium hover:bg-white"
                        >
                            Edit
                        </Link>
                    )}
                    <button
                        onClick={handleDelete}
                        className="bg-red-500/90 text-white px-3 py-1 rounded text-sm font-medium hover:bg-red-600"
                    >
                        Delete
                    </button>
                </div>

                <div className="text-white">
                    {wallpaper.type !== "MOBILE" && (
                        <p className="font-bold text-sm mb-1">
                            {wallpaper.releaseDate ? format(new Date(wallpaper.releaseDate), "yyyy-MM-dd") : "No Date"}
                        </p>
                    )}
                    {wallpaper.name && (
                        <p className="font-semibold text-sm truncate">
                            {wallpaper.name}
                            {wallpaper.artist ? <span className="font-normal opacity-75"> by {wallpaper.artist}</span> : ""}
                        </p>
                    )}
                    {wallpaper.description && <p className="text-xs opacity-90 line-clamp-2">{wallpaper.description}</p>}
                </div>
            </div>
        </div>
    );
}
