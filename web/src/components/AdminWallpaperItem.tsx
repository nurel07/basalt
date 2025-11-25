"use client";

import { format } from "date-fns";
import Link from "next/link";
import { useRouter } from "next/navigation";

interface Wallpaper {
    id: string;
    url: string;
    description: string | null;
    releaseDate: Date;
}

export default function AdminWallpaperItem({ wallpaper }: { wallpaper: Wallpaper }) {
    const router = useRouter();

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

    return (
        <div className="border rounded p-4 shadow bg-white text-black">
            <img
                src={wallpaper.url}
                alt={wallpaper.description || "Wallpaper"}
                className="w-full h-48 object-cover rounded mb-4"
            />
            <p className="font-bold">{format(new Date(wallpaper.releaseDate), "yyyy-MM-dd")}</p>
            <p className="text-gray-600 mb-4">{wallpaper.description}</p>
            <div className="flex gap-2">
                <Link
                    href={`/admin/wallpapers/${wallpaper.id}/edit`}
                    className="text-blue-500 hover:underline"
                >
                    Edit
                </Link>
                <button onClick={handleDelete} className="text-red-500 hover:underline">
                    Delete
                </button>
            </div>
        </div>
    );
}
