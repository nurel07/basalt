"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { analyzeImage } from "@/app/actions/analyze";



export interface Wallpaper {
    id: string;
    url: string;
    name: string | null;
    description: string | null;
    externalUrl: string | null;
    channel: string | null;
    releaseDate: Date | string;
}

interface UploadModalProps {
    isOpen: boolean;
    onClose: () => void;
    file: File | null;
    previewUrl: string;
    wallpaper?: Wallpaper;
    mode?: "UPLOAD" | "RESCHEDULE" | "EDIT";
}

export default function UploadModal({ isOpen, onClose, file, previewUrl, wallpaper, mode = "UPLOAD" }: UploadModalProps) {
    const [name, setName] = useState("");
    const [description, setDescription] = useState("");
    const [externalUrl, setExternalUrl] = useState("");
    const [channel, setChannel] = useState("HUMAN");
    const [date, setDate] = useState("");

    const [isUploading, setIsUploading] = useState(false);
    const [uploadedUrl, setUploadedUrl] = useState("");
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [isAnalyzing, setIsAnalyzing] = useState(false);

    const router = useRouter();

    // Reset form and start upload when modal opens
    useEffect(() => {
        if (!isOpen) return;

        if (mode === "RESCHEDULE" && wallpaper) {
            // Pre-fill for Rescheduling
            setName(wallpaper.name || "");
            setDescription(wallpaper.description || "");
            setExternalUrl(wallpaper.externalUrl || "");
            const currentChannel = wallpaper.channel || "HUMAN";
            setChannel(currentChannel);
            setUploadedUrl(wallpaper.url);

            // For reschedule, we want the NEXT available date for this channel
            fetchNextDate(currentChannel);

        } else if (mode === "EDIT" && wallpaper) {
            // Edit existing
            setName(wallpaper.name || "");
            setDescription(wallpaper.description || "");
            setExternalUrl(wallpaper.externalUrl || "");
            setChannel(wallpaper.channel || "HUMAN");
            setUploadedUrl(wallpaper.url);

            // Set existing date
            // Ensure we handle both Date object or string
            const d = new Date(wallpaper.releaseDate);
            setDate(d.toISOString().split('T')[0]);

        } else if (file) {
            // New Upload
            setName("");
            setDescription("");
            setExternalUrl("");
            setChannel("HUMAN");
            setUploadedUrl("");

            // Fetch next available date
            fetchNextDate("HUMAN");

            // Start Upload Immediately
            handleUpload(file);
        }
    }, [isOpen, file, wallpaper, mode]);

    // Fetch next available date when channel changes
    useEffect(() => {
        if (isOpen && mode !== "EDIT") {
            fetchNextDate(channel);
        }
    }, [isOpen, channel, mode]);

    const fetchNextDate = (selectedChannel: string) => {
        fetch(`/api/wallpapers/next-date?channel=${selectedChannel}`)
            .then(res => res.json())
            .then(data => {
                if (data.date) {
                    setDate(data.date);
                } else {
                    // Fallback to tomorrow if API fails
                    const tomorrow = new Date();
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    setDate(tomorrow.toISOString().split('T')[0]);
                }
            })
            .catch(err => {
                console.error("Failed to fetch next date:", err);
                // Fallback
                const tomorrow = new Date();
                tomorrow.setDate(tomorrow.getDate() + 1);
                setDate(tomorrow.toISOString().split('T')[0]);
            });
    };

};

const handleAnalyze = async () => {
    if (!uploadedUrl) return;
    setIsAnalyzing(true);
    try {
        const data = await analyzeImage(uploadedUrl);

        if (data.title) setName(data.title);

        let desc = data.description || "";
        if (data.artist && data.artist !== "Unknown") {
            desc += `\n\nArtist: ${data.artist}`;
        }
        if (data.date) {
            desc += `\n\nDate: ${data.date}`;
        }
        if (data.tags && Array.isArray(data.tags)) {
            desc += `\nTags: ${data.tags.join(", ")}`;
        }

        setDescription(desc);

    } catch (error) {
        console.error("Analysis error:", error);
        alert("Failed to analyze image with AI.");
    } finally {
        setIsAnalyzing(false);
    }
};

const handleUpload = async (file: File) => {
    setIsUploading(true);
    try {
        // 1. Get signature
        const signRes = await fetch("/api/cloudinary/sign", { method: "POST" });
        if (!signRes.ok) throw new Error("Failed to get upload signature");
        const { signature, timestamp, cloudName, apiKey } = await signRes.json();

        // 2. Upload to Cloudinary
        const formData = new FormData();
        formData.append("file", file);
        formData.append("api_key", apiKey);
        formData.append("timestamp", timestamp.toString());
        formData.append("signature", signature);
        formData.append("folder", "wallpapers");

        const uploadRes = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
            method: "POST",
            body: formData,
        });

        if (!uploadRes.ok) {
            const errorData = await uploadRes.json();
            throw new Error(errorData.error?.message || "Upload failed");
        }

        const data = await uploadRes.json();
        setUploadedUrl(data.secure_url);
    } catch (error: any) {
        console.error("Upload error:", error);
        alert(`Upload failed: ${error.message}`);
        onClose(); // Close on upload failure? Or let them retry?
    } finally {
        setIsUploading(false);
    }
};

const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!uploadedUrl) {
        alert("Please wait for the image to finish uploading.");
        return;
    }

    setIsSubmitting(true);

    try {
        let res;
        if (wallpaper) {
            // Update existing
            res = await fetch(`/api/wallpapers/${wallpaper.id}`, {
                method: "PUT",
                body: JSON.stringify({
                    name,
                    description,
                    externalUrl,
                    channel,
                    releaseDate: date,
                }),
            });
        } else {
            // Create new
            res = await fetch("/api/wallpapers", {
                method: "POST",
                body: JSON.stringify({
                    url: uploadedUrl,
                    name,
                    description,
                    externalUrl,
                    channel,
                    releaseDate: date,
                }),
            });
        }

        if (res.ok) {
            router.refresh();
            onClose();
        } else {
            alert("Error creating wallpaper");
        }
    } catch (error) {
        console.error("Submission error:", error);
        alert("Error creating wallpaper");
    } finally {
        setIsSubmitting(false);
    }
};

if (!isOpen) return null;

return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-md w-full overflow-hidden flex flex-col max-h-[90vh]">
            <div className="p-6 overflow-y-auto">
                <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">Add Details</h2>

                <div className="mb-6 rounded-lg overflow-hidden aspect-video bg-gray-100 relative group">
                    <img src={previewUrl || uploadedUrl} alt="Preview" className={`absolute inset-0 w-full h-full object-cover ${isUploading ? 'opacity-50' : ''}`} />

                    {isUploading && (
                        <div className="absolute inset-0 flex items-center justify-center">
                            <div className="bg-black/50 text-white px-4 py-2 rounded-full text-sm font-medium flex items-center gap-2">
                                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                Uploading...
                            </div>
                        </div>
                    )}

                    {!isUploading && uploadedUrl && (
                        <div className="absolute bottom-2 right-2 bg-green-500 text-white text-xs px-2 py-1 rounded shadow">
                            Uploaded
                        </div>

                    )}

                    {!isUploading && uploadedUrl && (
                        <button
                            type="button"
                            onClick={handleAnalyze}
                            disabled={isAnalyzing}
                            className="absolute bottom-2 left-2 bg-purple-600 text-white text-xs px-3 py-1.5 rounded shadow flex items-center gap-1.5 hover:bg-purple-700 transition-colors disabled:opacity-50"
                        >
                            {isAnalyzing ? (
                                <>
                                    <div className="w-3 h-3 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                    Analyzing...
                                </>
                            ) : (
                                <>
                                    ✨ Analyze with AI
                                </>
                            )}
                        </button>
                    )}
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Name</label>
                        <input
                            type="text"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                            placeholder="Wallpaper Name"
                        />
                    </div>

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
                        <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">URL</label>
                        <input
                            type="url"
                            value={externalUrl}
                            onChange={(e) => setExternalUrl(e.target.value)}
                            className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                            placeholder="https://..."
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Channel</label>
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
                            disabled={isSubmitting || isUploading}
                            className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium flex items-center gap-2"
                        >
                            {isSubmitting ? "Saving..." : isUploading ? "Uploading..." : "Save Wallpaper"}
                        </button>
                    </div>
                </form>
            </div>
        </div>

        );
}
