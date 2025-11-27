"use client";

import { useUploadThing } from "@/lib/uploadthing";
import { useState, useRef } from "react";
import { Upload } from "lucide-react";
import UploadModal from "./UploadModal";

export default function UploadCell() {
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [uploadedImageUrl, setUploadedImageUrl] = useState("");
    const [isUploading, setIsUploading] = useState(false);
    const fileInputRef = useRef<HTMLInputElement>(null);

    const { startUpload } = useUploadThing("imageUploader", {
        onClientUploadComplete: (res) => {
            console.log("Upload completed:", res);
            setIsUploading(false);
            if (res && res[0]) {
                setUploadedImageUrl(res[0].url);
                setIsModalOpen(true);
            }
        },
        onUploadError: (error: Error) => {
            console.error("Upload error:", error);
            setIsUploading(false);
            alert(`ERROR! ${error.message} `);
        },
        onUploadBegin: () => {
            console.log("Upload started...");
            setIsUploading(true);
        },
    });

    const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const files = e.target.files;
        if (!files || files.length === 0) return;

        await startUpload(Array.from(files));
    };

    return (
        <>
            <div
                className="relative w-full h-auto aspect-[16/10] bg-gray-100 dark:bg-gray-800 flex flex-col items-center justify-center overflow-hidden group cursor-pointer"
                onClick={() => fileInputRef.current?.click()}
            >

                {/* Hidden File Input */}
                <input
                    type="file"
                    ref={fileInputRef}
                    className="hidden"
                    accept="image/*"
                    onChange={handleFileSelect}
                    disabled={isUploading}
                />

                {/* Visual Content */}
                <div className="flex flex-col items-center text-gray-400 group-hover:text-blue-500 transition-colors pointer-events-none z-10">
                    {isUploading ? (
                        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mb-2"></div>
                    ) : (
                        <Upload className="w-12 h-12 mb-2" />
                    )}
                    <span className="font-medium">{isUploading ? "Uploading..." : "Upload Image"}</span>
                </div>
            </div>

            <UploadModal
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                imageUrl={uploadedImageUrl}
            />
        </>
    );
}
