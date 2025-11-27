"use client";

import { UploadDropzone } from "@/lib/uploadthing";
import { useState } from "react";
import { Upload } from "lucide-react";
import UploadModal from "./UploadModal";

export default function UploadCell() {
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [uploadedImageUrl, setUploadedImageUrl] = useState("");
    const [isUploading, setIsUploading] = useState(false);

    const handleUploadComplete = (res: any) => {
        setIsUploading(false);
        if (res && res[0]) {
            setUploadedImageUrl(res[0].url);
            setIsModalOpen(true);
        }
    };

    return (
        <>
            <div className="relative w-full h-auto aspect-[16/10] bg-gray-100 dark:bg-gray-800 flex flex-col items-center justify-center overflow-hidden group cursor-pointer">

                {/* We overlay the UploadDropzone to cover the entire area */}
                <div className="absolute inset-0 z-20 opacity-0">
                    <UploadDropzone
                        endpoint="imageUploader"
                        onUploadBegin={() => {
                            console.log("Upload started...");
                            setIsUploading(true);
                        }}
                        onClientUploadComplete={(res) => {
                            console.log("Upload completed:", res);
                            handleUploadComplete(res);
                        }}
                        onUploadError={(error: Error) => {
                            console.error("Upload error:", error);
                            setIsUploading(false);
                            alert(`ERROR! ${error.message}`);
                        }}
                        appearance={{
                            container: { height: '100%', width: '100%', border: 'none' },
                            uploadIcon: { display: 'none' },
                            label: { display: 'none' },
                            allowedContent: { display: 'none' },
                            button: { display: 'none' },
                        }}
                    />
                </div>

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
