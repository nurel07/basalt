"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { analyzeImage } from "@/app/actions/analyze";
import { checkDuplicateTitle } from "@/app/actions/validation";



export interface Wallpaper {
    id: string;
    url: string;
    name: string | null;
    description: string | null;
    externalUrl: string | null;
    channel: string | null;
    type: "DESKTOP" | "MOBILE";
    collectionId: string | null;
    releaseDate: Date | string | null;
}

export interface MobileCollection {
    id: string;
    name: string;
    slug: string;
    description?: string | null;
    coverImage?: string;
}

interface UploadModalProps {
    isOpen: boolean;
    onClose: () => void;
    file: File | null;
    previewUrl: string;
    wallpaper?: Wallpaper;
    mode?: "UPLOAD" | "RESCHEDULE" | "EDIT";
    collections?: MobileCollection[]; // Optional because maybe not always loaded
    initialCollectionId?: string;
}

export default function UploadModal({ isOpen, onClose, file, previewUrl, wallpaper, mode = "UPLOAD", collections = [], initialCollectionId }: UploadModalProps) {
    const [name, setName] = useState("");
    const [description, setDescription] = useState("");
    const [externalUrl, setExternalUrl] = useState("");
    const [channel, setChannel] = useState("HUMAN");
    const [date, setDate] = useState("");

    // Type & Collection
    const [type, setType] = useState<"DESKTOP" | "MOBILE">(initialCollectionId ? "MOBILE" : "DESKTOP");
    const [collectionId, setCollectionId] = useState(initialCollectionId || "");

    // New Metadata Fields
    const [artist, setArtist] = useState("");
    const [creationDate, setCreationDate] = useState("");
    const [genre, setGenre] = useState("");
    const [movement, setMovement] = useState("");
    const [dominantColors, setDominantColors] = useState<string[]>([]);
    const [tags, setTags] = useState<string[]>([]);

    // Duplicate check state
    const [isDuplicate, setIsDuplicate] = useState(false);

    useEffect(() => {
        if (!name || channel !== "HUMAN") {
            setIsDuplicate(false);
            return;
        }

        const timer = setTimeout(async () => {
            const isDup = await checkDuplicateTitle(name, wallpaper?.id);
            setIsDuplicate(isDup);
        }, 500);

        return () => clearTimeout(timer);
    }, [name, channel, wallpaper?.id]);

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

            const wType = wallpaper.type || "DESKTOP";
            setType(wType);
            setCollectionId(wallpaper.collectionId || "");

            // New fields might not exist on old wallpapers, default to empty
            setArtist((wallpaper as any).artist || "");
            setCreationDate((wallpaper as any).creationDate || "");
            setGenre((wallpaper as any).genre || "");
            setMovement((wallpaper as any).movement || "");
            setDominantColors((wallpaper as any).dominantColors || []);
            setTags((wallpaper as any).tags || []);

            // For reschedule, we want the NEXT available date for this channel
            fetchNextDate(currentChannel);

        } else if (mode === "EDIT" && wallpaper) {
            // Edit existing
            setName(wallpaper.name || "");
            setDescription(wallpaper.description || "");
            setExternalUrl(wallpaper.externalUrl || "");
            setChannel(wallpaper.channel || "HUMAN");
            setUploadedUrl(wallpaper.url);

            const wType = wallpaper.type || "DESKTOP";
            setType(wType);
            setCollectionId(wallpaper.collectionId || "");

            setArtist((wallpaper as any).artist || "");
            setCreationDate((wallpaper as any).creationDate || "");
            setGenre((wallpaper as any).genre || "");
            setMovement((wallpaper as any).movement || "");
            setDominantColors((wallpaper as any).dominantColors || []);
            setTags((wallpaper as any).tags || []);

            // Set existing date
            if (wallpaper.releaseDate) {
                const d = new Date(wallpaper.releaseDate);
                setDate(d.toISOString().split('T')[0]);
            } else {
                setDate("");
            }

        } else if (file) {
            // New Upload
            setName("");
            setDescription("");
            setExternalUrl("");
            setChannel("HUMAN");
            setUploadedUrl("");
            setType(initialCollectionId ? "MOBILE" : "DESKTOP");
            setCollectionId(initialCollectionId || "");
            setArtist("");
            setCreationDate("");
            setGenre("");
            setMovement("");
            setDominantColors([]);
            setTags([]);

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
                    const tomorrow = new Date();
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    setDate(tomorrow.toISOString().split('T')[0]);
                }
            })
            .catch(err => {
                console.error("Failed to fetch next date:", err);
                const tomorrow = new Date();
                tomorrow.setDate(tomorrow.getDate() + 1);
                setDate(tomorrow.toISOString().split('T')[0]);
            });
    };



    const handleAnalyze = async () => {
        if (!uploadedUrl) return;
        setIsAnalyzing(true);
        try {
            const data = await analyzeImage(uploadedUrl);

            // Channel Detection
            if (data.channel) setChannel(data.channel);

            // Basic Info
            if (data.title) setName(data.title);
            if (data.description) setDescription(data.description);

            // Rich Metadata
            if (data.channel === "HUMAN") {
                if (data.artist) setArtist(data.artist);
                if (data.creationDate) setCreationDate(data.creationDate);
                if (data.genre) setGenre(data.genre);
                if (data.movement) setMovement(data.movement);
                if (data.dominantColors) setDominantColors(data.dominantColors);
                if (data.tags) setTags(data.tags);
            } else {
                // Reset if AI detects it as AI generated
                setArtist("");
                setCreationDate("");
                setGenre("");
                setMovement("");
            }

        } catch (error: any) {
            console.error("Analysis error:", error);
            alert(`Analysis failed: ${error.message}`);
        } finally {
            setIsAnalyzing(false);
        }
    };

    const handleUpload = async (file: File) => {
        setIsUploading(true);
        try {
            const signRes = await fetch("/api/cloudinary/sign", { method: "POST" });
            if (!signRes.ok) throw new Error("Failed to get upload signature");
            const { signature, timestamp, cloudName, apiKey } = await signRes.json();

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
            onClose();
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

        const payload = {
            name,
            description,
            externalUrl,
            channel,
            releaseDate: date,
            artist,
            creationDate,
            genre,
            movement,
            dominantColors,
            tags,
            type,
            collectionId: type === "MOBILE" ? collectionId : null
        };

        try {
            let res;
            if (wallpaper) {
                // Update existing
                res = await fetch(`/api/wallpapers/${wallpaper.id}`, {
                    method: "PUT",
                    body: JSON.stringify(payload),
                });
            } else {
                // Create new
                res = await fetch("/api/wallpapers", {
                    method: "POST",
                    body: JSON.stringify({ ...payload, url: uploadedUrl }),
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
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-2xl w-full overflow-hidden flex flex-col max-h-[90vh]">
                <form onSubmit={handleSubmit} className="p-6 overflow-y-auto grid grid-cols-1 md:grid-cols-2 gap-6">

                    {/* Left Column: Preview + Basic Info */}
                    <div className="space-y-4">
                        <div className="rounded-lg overflow-hidden aspect-video bg-gray-100 relative group">
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
                                <button
                                    type="button"
                                    onClick={handleAnalyze}
                                    disabled={isAnalyzing}
                                    className="absolute bottom-2 left-2 right-2 bg-gradient-to-r from-purple-600 to-blue-600 text-white text-sm px-3 py-2 rounded shadow flex items-center justify-center gap-2 hover:opacity-90 transition-all disabled:opacity-50"
                                >
                                    {isAnalyzing ? (
                                        <>
                                            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                            Analyzing Art...
                                        </>
                                    ) : (
                                        <>
                                            ✨ Analyze with AI
                                        </>
                                    )}
                                </button>
                            )}
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Title</label>
                            <input
                                type="text"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                className={`w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 outline-none transition-all ${isDuplicate
                                    ? "border-yellow-500 focus:ring-yellow-500"
                                    : "border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500"
                                    }`}
                                placeholder="Artwork Title"
                            />
                            {isDuplicate && (
                                <p className="text-xs text-yellow-600 dark:text-yellow-400 mt-1 flex items-center gap-1">
                                    ⚠️ Warning: A wallpaper with this title already exists.
                                </p>
                            )}
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Description</label>
                            <textarea
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                rows={4}
                                placeholder="Enter a description..."
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Tags</label>
                            <input
                                type="text"
                                value={tags.join(", ")}
                                onChange={(e) => setTags(e.target.value.split(",").map(t => t.trim()))}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                placeholder="landscape, impressionism, oil"
                            />
                        </div>
                    </div>

                    {/* Right Column: Metadata */}
                    <div className="space-y-4">
                        <h3 className="font-semibold text-gray-900 dark:text-white border-b pb-2">Details</h3>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Artist</label>
                            <input
                                type="text"
                                value={artist}
                                onChange={(e) => setArtist(e.target.value)}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                placeholder="Vincent van Gogh"
                            />
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Year</label>
                                <input
                                    type="text"
                                    value={creationDate}
                                    onChange={(e) => setCreationDate(e.target.value)}
                                    className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                    placeholder="1889"
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Genre</label>
                                <input
                                    type="text"
                                    value={genre}
                                    onChange={(e) => setGenre(e.target.value)}
                                    className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                    placeholder="Landscape"
                                />
                            </div>
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Movement</label>
                            <input
                                type="text"
                                value={movement}
                                onChange={(e) => setMovement(e.target.value)}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                placeholder="Post-Impressionism"
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Dominant Colors</label>
                            <div className="flex gap-2 mb-2 flex-wrap">
                                {dominantColors.map((color, i) => (
                                    <div key={i} className="w-8 h-8 rounded-full shadow border border-gray-200" style={{ backgroundColor: color }} title={color} />
                                ))}
                            </div>
                            <input
                                type="text"
                                value={dominantColors.join(", ")}
                                onChange={(e) => setDominantColors(e.target.value.split(",").map(c => c.trim()))}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none text-xs"
                                placeholder="#FF0000, #00FF00"
                            />
                        </div>


                        <div className="pt-4 border-t">
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">Channel</label>
                            <div className="flex gap-4 p-2 bg-gray-50 dark:bg-gray-700 rounded-lg">
                                <label className="flex items-center gap-2 cursor-pointer">
                                    <input
                                        type="radio"
                                        name="channel"
                                        value="HUMAN"
                                        checked={channel === "HUMAN"}
                                        onChange={(e) => setChannel(e.target.value)}
                                        className="w-4 h-4 text-blue-600"
                                    />
                                    <span className="text-gray-700 dark:text-gray-300 font-medium">Fine Art (Human)</span>
                                </label>
                                <label className="flex items-center gap-2 cursor-pointer">
                                    <input
                                        type="radio"
                                        name="channel"
                                        value="AI"
                                        checked={channel === "AI"}
                                        onChange={(e) => setChannel(e.target.value)}
                                        className="w-4 h-4 text-purple-600"
                                    />
                                    <span className="text-purple-600 dark:text-purple-300 font-medium">AI Generated</span>
                                </label>
                            </div>
                        </div>

                        {type === "DESKTOP" && (
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
                        )}
                        <div>
                            <label className="block text-sm font-medium mb-1 text-gray-700 dark:text-gray-300">External URL</label>
                            <input
                                type="url"
                                value={externalUrl}
                                onChange={(e) => setExternalUrl(e.target.value)}
                                className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-700 border-gray-200 dark:border-gray-600 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                placeholder="https://..."
                            />
                        </div>

                        <div className="flex justify-end gap-3 pt-4">
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
                    </div>
                </form>
            </div>
        </div>
    );
}
