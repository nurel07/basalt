"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";

interface UploadModalProps {
    isOpen: boolean;
    onClose: () => void;
    imageUrl: string;
}

export default function UploadModal({ isOpen, onClose, imageUrl }: UploadModalProps) {
    const [description, setDescription] = useState("");
    const [date, setDate] = useState("");
    const [isSubmitting, setIsSubmitting] = useState(false);
    const router = useRouter();

    // Reset form when modal opens with a new image
    useEffect(() => {
        if (isOpen) {
            setDescription("");
            setDate(new Date().toISOString().split('T')[0]); // Default to today
        }
    }, [isOpen, imageUrl]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsSubmitting(true);

        try {
            const res = await fetch("/api/wallpapers", {
                method: "POST",
                body: JSON.stringify({
                    url: imageUrl,
                    description,
                    releaseDate: date,
                }),
            });

            if (res.ok) {
                router.refresh();
                onClose();
            } else {
                alert("Error creating wallpaper");
            }
        } catch (error) {
            console.error("Upload error:", error);
            alert("Error creating wallpaper");
        } finally {
            setIsSubmitting(false);
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-md w-full overflow-hidden">
                <div className="p-6">
                    <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">Add Details</h2>

                    <div className="mb-6 rounded-lg overflow-hidden aspect-video bg-gray-100 relative">
                        <img src={imageUrl} alt="Preview" className="absolute inset-0 w-full h-full object-cover" />
                    </div>

                    <form onSubmit={handleSubmit} className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Description</label>
                            <textarea
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                rows={3}
                                placeholder="Enter a description..."
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Release Date</label>
                            <input
                                type="date"
                                value={date}
                                onChange={(e) => setDate(e.target.value)}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                required
                            />
                        </div>

                        <div className="flex justify-end gap-3 mt-6">
                            <button
                                type="button"
                                onClick={onClose}
                                className="px-4 py-2 text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-white transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                type="submit"
                                disabled={isSubmitting}
                                className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
                            >
                                {isSubmitting ? "Saving..." : "Save Wallpaper"}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    );
}
