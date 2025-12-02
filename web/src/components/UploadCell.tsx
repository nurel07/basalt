"use client";

import { useState, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { Upload, Loader2 } from "lucide-react";
import UploadModal from "./UploadModal";

export default function UploadCell() {
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [previewUrl, setPreviewUrl] = useState("");

    const onDrop = useCallback((acceptedFiles: File[]) => {
        const file = acceptedFiles[0];
        if (!file) return;

        // Create local preview
        const objectUrl = URL.createObjectURL(file);
        setPreviewUrl(objectUrl);
        setSelectedFile(file);
        setIsModalOpen(true);
    }, []);

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop,
        accept: {
            'image/*': []
        },
        multiple: false
    });

    return (
        <>
            <div
                {...getRootProps()}
                className={`relative w-full h-auto aspect-[16/10] bg-gray-100 dark:bg-gray-800 flex flex-col items-center justify-center overflow-hidden group cursor-pointer transition-colors
                    ${isDragActive ? 'border-2 border-blue-500 bg-blue-50 dark:bg-blue-900/20' : ''}
                `}
            >
                <input {...getInputProps()} />

                {/* Visual Content */}
                <div className="flex flex-col items-center text-gray-400 group-hover:text-blue-500 transition-colors z-10">
                    <Upload className={`w-12 h-12 mb-2 ${isDragActive ? 'animate-bounce' : ''}`} />
                    <span className="font-medium">
                        {isDragActive ? "Drop it here!" : "Upload Image"}
                    </span>
                    {!isDragActive && (
                        <span className="text-xs mt-1 opacity-70">Drag & drop or click</span>
                    )}
                </div>
            </div>

            <UploadModal
                isOpen={isModalOpen}
                onClose={() => {
                    setIsModalOpen(false);
                    // Cleanup preview URL to avoid memory leaks
                    if (previewUrl) URL.revokeObjectURL(previewUrl);
                    setPreviewUrl("");
                    setSelectedFile(null);
                }}
                file={selectedFile}
                previewUrl={previewUrl}
            />
        </>
    );
}
