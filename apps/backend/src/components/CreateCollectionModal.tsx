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
                setIsSlugManuallyEdited(true); // Don't auto-update slug when editing existing
            } else {
                setName("");
                setSlug("");
                setDescription("");
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



    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!name || !slug) return;

        setIsSubmitting(true);
        try {
            let res;
            if (initialData) {
                // UPDATE - preserve existing coverImage (backend handles it if missing, or we send partial)
                // Actually the API expects full object usually, but let's check. 
                // Using initialData.coverImage ensures we don't break it. 
                // But wait, if we want to NOT change it, we should just send what we have or let API handle it.
                // Best approach: Send initialData.coverImage.
                res = await fetch(`/api/collections/${initialData.id}`, {
                    method: "PUT",
                    body: JSON.stringify({ name, slug, description, coverImage: initialData.coverImage }),
                });
            } else {
                // CREATE - Use a placeholder
                const PLACEHOLDER_COVER = "https://placehold.co/600x800/222222/FFFFFF/png?text=Collection";
                res = await fetch("/api/collections", {
                    method: "POST",
                    body: JSON.stringify({ name, slug, description, coverImage: PLACEHOLDER_COVER }),
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
                            disabled={isSubmitting || isUploading || !name}
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
