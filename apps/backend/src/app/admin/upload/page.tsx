"use client";

import { UploadDropzone } from "@/lib/uploadthing";
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function UploadPage() {
    const [imageUrl, setImageUrl] = useState("");
    const [description, setDescription] = useState("");
    const [date, setDate] = useState("");
    const router = useRouter();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!imageUrl) return alert("Please upload an image");

        const res = await fetch("/api/wallpapers", {
            method: "POST",
            body: JSON.stringify({
                url: imageUrl,
                description,
                releaseDate: date,
            }),
        });

        if (res.ok) {
            router.push("/admin");
        } else {
            alert("Error creating wallpaper");
        }
    };

    return (
        <div className="p-8 max-w-2xl mx-auto">
            <h1 className="text-3xl font-bold mb-8">Upload Wallpaper</h1>

            <div className="mb-8">
                <label className="block mb-2 font-bold">Image</label>
                {imageUrl ? (
                    <div className="mb-4">
                        <img src={imageUrl} alt="Uploaded" className="max-h-64 rounded" />
                        <button
                            onClick={() => setImageUrl("")}
                            className="text-red-500 text-sm mt-2"
                        >
                            Remove
                        </button>
                    </div>
                ) : (
                    <UploadDropzone
                        endpoint="imageUploader"
                        onClientUploadComplete={(res) => {
                            if (res && res[0]) {
                                setImageUrl(res[0].url);
                            }
                        }}
                        onUploadError={(error: Error) => {
                            alert(`ERROR! ${error.message}`);
                        }}
                    />
                )}
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
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
                    <label className="block mb-2 font-bold">Release Date</label>
                    <input
                        type="date"
                        value={date}
                        onChange={(e) => setDate(e.target.value)}
                        className="w-full p-2 border rounded text-black"
                        required
                    />
                </div>

                <button
                    type="submit"
                    className="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600"
                >
                    Save Wallpaper
                </button>
            </form>
        </div>
    );
}
