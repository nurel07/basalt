import React from "react";

interface MasonryGridProps {
    children: React.ReactNode;
    className?: string;
    gap?: string;
}

export default function MasonryGrid({ children, className = "", gap = "gap-6 space-y-6" }: MasonryGridProps) {
    return (
        <div className={`columns-1 md:columns-2 lg:columns-3 ${gap} ${className}`}>
            {/* 
              We use 'break-inside-avoid' on children to prevent them from being split across columns.
            */}
            {React.Children.map(children, (child) => (
                <div className={`break-inside-avoid ${gap === "gap-0 space-y-0" ? "mb-0" : "mb-6"}`}>
                    {child}
                </div>
            ))}
        </div>
    );
}
