"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { format } from "date-fns";

interface Wallpaper {
    id: string;
    url: string;
    name: string | null;
    description: string | null;
    externalUrl: string | null;
    channel: string;
    releaseDate: Date;
}

export default function EditWallpaperForm({ wallpaper }: { wallpaper: Wallpaper }) {
    const [name, setName] = useState(wallpaper.name || "");
    const [description, setDescription] = useState(wallpaper.description || "");
    const [externalUrl, setExternalUrl] = useState(wallpaper.externalUrl || "");
    const [channel, setChannel] = useState(wallpaper.channel || "HUMAN");
    const [date, setDate] = useState(
        wallpaper.releaseDate ? format(new Date(wallpaper.releaseDate), "yyyy-MM-dd") : ""
    );
    const router = useRouter();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        const res = await fetch(`/api/wallpapers/${wallpaper.id}`, {
            method: "PUT",
            body: JSON.stringify({
                name,
                description,
                externalUrl,
                channel,
                releaseDate: date,
            }),
        });

        if (res.ok) {
            router.push("/admin");
            router.refresh();
        } else {
            alert("Error updating wallpaper");
        }
    };

    return (
        <div>
            <div className="mb-8">
                <label className="block mb-2 font-bold">Image</label>
                <img src={wallpaper.url} alt="Wallpaper" className="max-h-64 rounded" />
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                    <label className="block mb-2 font-bold">Name</label>
                    <input
                        type="text"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        className="w-full p-2 border rounded text-black"
                    />
                </div>

                <div>
                    <label className="block mb-2 font-bold">Description</label>
                    <textarea
                        value={description}
                        onChange={(e) => setDescription(e.target.value)}
                        className="w-full p-2 border rounded text-black"
                        rows={3}
                    />
                </div>

                <div>
                    <label className="block mb-2 font-bold">External URL</label>
                    <input
                        type="url"
                        value={externalUrl}
                        onChange={(e) => setExternalUrl(e.target.value)}
                        className="w-full p-2 border rounded text-black"
                    />
                </div>

                <div>
                    <label className="block mb-2 font-bold">Channel</label>
                    <div className="flex gap-4">
                        <label className="flex items-center gap-2 cursor-pointer">
                            <input
                                type="radio"
                                name="channel"
                                value="HUMAN"
                                checked={channel === "HUMAN"}
                                onChange={(e) => setChannel(e.target.value)}
                                className="w-4 h-4 text-blue-600"
                            />
                            <span className="text-gray-700 dark:text-gray-300">Human</span>
                        </label>
                        <label className="flex items-center gap-2 cursor-pointer">
                            <input
                                type="radio"
                                name="channel"
                                value="AI"
                                checked={channel === "AI"}
                                onChange={(e) => setChannel(e.target.value)}
                                className="w-4 h-4 text-blue-600"
                            />
                            <span className="text-gray-700 dark:text-gray-300">AI</span>
                        </label>
                    </div>
                </div>

                <div>
                    <label className="block mb-2 font-bold">Release Date</label>
                    <input
                        type="date"
                        value={date}
                        onChange={(e) => setDate(e.target.value)}
                        className="w-full p-2 border rounded text-black"
                        required
                    />
                </div>

                <div className="flex gap-4">
                    <button
                        type="submit"
                        className="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600"
                    >
                        Save Changes
                    </button>
                    <button
                        type="button"
                        onClick={() => router.back()}
                        className="bg-gray-500 text-white px-6 py-2 rounded hover:bg-gray-600"
                    >
                        Cancel
                    </button>
                </div>
            </form>
        </div>
    );
}
