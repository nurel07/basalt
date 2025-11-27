"use client";

import { UploadDropzone } from "@/lib/uploadthing";
import { useState } from "react";
import { ArrowUpTrayIcon } from "@heroicons/react/24/outline";
import UploadModal from "./UploadModal";

export default function UploadCell() {
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [uploadedImageUrl, setUploadedImageUrl] = useState("");

    const handleUploadComplete = (res: any) => {
        if (res && res[0]) {
            setUploadedImageUrl(res[0].url);
            setIsModalOpen(true);
        }
    };

    return (
        <>
            <div className="relative aspect-[16/10] rounded-xl border-2 border-dashed border-gray-300 dark:border-gray-700 hover:border-blue-500 dark:hover:border-blue-400 transition-colors bg-gray-50 dark:bg-gray-800/50 flex flex-col items-center justify-center overflow-hidden group">

                {/* We overlay the UploadDropzone to cover the entire area */}
                <div className="absolute inset-0 z-10 opacity-0 cursor-pointer">
                    <UploadDropzone
                        endpoint="imageUploader"
                        onClientUploadComplete={handleUploadComplete}
                        onUploadError={(error: Error) => {
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
                <div className="flex flex-col items-center text-gray-400 group-hover:text-blue-500 transition-colors pointer-events-none">
                    <ArrowUpTrayIcon className="w-12 h-12 mb-2" />
                    <span className="font-medium">Upload Image</span>
                    <span className="text-xs mt-1 opacity-70">Drag & drop or click</span>
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
