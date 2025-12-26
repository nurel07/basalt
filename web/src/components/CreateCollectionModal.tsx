import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { MobileCollection } from "./UploadModal";

interface CreateCollectionModalProps {
    isOpen: boolean;
    onClose: () => void;
    initialData?: MobileCollection;
}

export default function CreateCollectionModal({ isOpen, onClose, initialData }: CreateCollectionModalProps) {
    const [name, setName] = useState("");
    const [slug, setSlug] = useState("");
    const [description, setDescription] = useState("");
    const [coverImage, setCoverImage] = useState("");

    // Track if user manually edited slug to avoid auto-generating it on name change if they customized it
    const [isSlugManuallyEdited, setIsSlugManuallyEdited] = useState(false);

    const [isUploading, setIsUploading] = useState(false);
    const [isSubmitting, setIsSubmitting] = useState(false);

    const router = useRouter();

    // Reset or Initialize form when modal opens or initialData changes
    useEffect(() => {
        if (isOpen) {
            if (initialData) {
                setName(initialData.name);
                setSlug(initialData.slug);
                setDescription(initialData.description || "");
                setCoverImage(initialData.coverImage || "");
                setIsSlugManuallyEdited(true); // Don't auto-update slug when editing existing
            } else {
                setName("");
                setSlug("");
                setDescription("");
                setCoverImage("");
                setIsSlugManuallyEdited(false);
            }
        }
    }, [isOpen, initialData]);

    if (!isOpen) return null;

    const generateSlug = (val: string) => {
        return val.toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/(^-|-$)+/g, '');
    };

    const handleNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const val = e.target.value;
        setName(val);
        if (!isSlugManuallyEdited && !initialData) {
            setSlug(generateSlug(val));
        }
    };

    const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setIsUploading(true);
        try {
            const signRes = await fetch("/api/cloudinary/sign", {
                method: "POST",
                body: JSON.stringify({ folder: "collections" }),
            });
            if (!signRes.ok) throw new Error("Failed to get upload signature");
            const { signature, timestamp, cloudName, apiKey } = await signRes.json();

            const formData = new FormData();
            formData.append("file", file);
            formData.append("api_key", apiKey);
            formData.append("timestamp", timestamp.toString());
            formData.append("signature", signature);
            formData.append("folder", "collections");

            const uploadRes = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
                method: "POST",
                body: formData,
            });

            if (!uploadRes.ok) throw new Error("Upload failed");

            const data = await uploadRes.json();
            setCoverImage(data.secure_url);
        } catch (error) {
            console.error("Upload error:", error);
            alert("Failed to upload cover image");
        } finally {
            setIsUploading(false);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!name || !slug || !coverImage) return;

        setIsSubmitting(true);
        try {
            let res;
            if (initialData) {
                // UPDATE
                res = await fetch(`/api/collections/${initialData.id}`, {
                    method: "PUT",
                    body: JSON.stringify({ name, slug, description, coverImage }),
                });
            } else {
                // CREATE
                res = await fetch("/api/collections", {
                    method: "POST",
                    body: JSON.stringify({ name, slug, description, coverImage }),
                });
            }

            if (res.ok) {
                router.refresh();
                onClose();
            } else {
                alert("Error saving collection");
            }
        } catch (error) {
            console.error("Error:", error);
            alert("Error saving collection");
        } finally {
            setIsSubmitting(false);
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-md w-full overflow-hidden">
                <form onSubmit={handleSubmit} className="p-6 space-y-4">
                    <h2 className="text-xl font-bold dark:text-white">
                        {initialData ? "Edit Collection" : "New Collection"}
                    </h2>

                    <div>
                        <label className="block text-sm font-medium mb-1 dark:text-gray-300">Name</label>
                        <input
                            type="text"
                            value={name}
                            onChange={handleNameChange}
                            className="w-full p-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="e.g. Abstract Textures"
                            required
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium mb-1 dark:text-gray-300">Slug</label>
                        <input
                            type="text"
                            value={slug}
                            onChange={(e) => {
                                setSlug(e.target.value);
                                setIsSlugManuallyEdited(true);
                            }}
                            className="w-full p-2 border rounded-lg bg-gray-50 dark:bg-gray-900 dark:border-gray-700 outline-none text-sm font-mono text-gray-500"
                            placeholder="abstract-textures"
                            required
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium mb-1 dark:text-gray-300">Description</label>
                        <textarea
                            value={description}
                            onChange={(e) => setDescription(e.target.value)}
                            className="w-full p-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 outline-none focus:ring-2 focus:ring-blue-500"
                            rows={3}
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium mb-1 dark:text-gray-300">Cover Image</label>
                        <div className="relative aspect-[4/3] bg-gray-100 dark:bg-gray-700 rounded-lg overflow-hidden border-2 border-dashed border-gray-300 dark:border-gray-600 flex items-center justify-center group">
                            {coverImage ? (
                                <img src={coverImage} alt="Cover" className="absolute inset-0 w-full h-full object-cover" />
                            ) : (
                                <div className="text-gray-400 text-sm">
                                    {isUploading ? "Uploading..." : "Click to Upload"}
                                </div>
                            )}
                            <input
                                type="file"
                                onChange={handleUpload}
                                className="absolute inset-0 opacity-0 cursor-pointer"
                                accept="image/*"
                                disabled={isUploading}
                            />
                        </div>
                    </div>

                    <div className="flex justify-end gap-3 pt-4 border-t dark:border-gray-700">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-4 py-2 text-gray-600 hover:text-gray-800 dark:text-gray-400"
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            disabled={isSubmitting || isUploading || !name || !coverImage}
                            className="bg-pink-600 text-white px-6 py-2 rounded-lg hover:bg-pink-700 disabled:opacity-50 transition-colors font-medium"
                        >
                            {isSubmitting ? "Saving..." : (initialData ? "Save Changes" : "Create Collection")}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}
