"use client";

import React, { useEffect, useState } from "react";

interface MasonryGridProps {
    children: React.ReactNode;
    className?: string;
    gap?: string;
    variant?: "standard" | "dense";
}

export default function MasonryGrid({ children, className = "", gap = "gap-6", variant = "standard" }: MasonryGridProps) {
    const [columns, setColumns] = useState(1);

    useEffect(() => {
        const updateColumns = () => {
            const width = window.innerWidth;

            if (variant === "dense") {
                // Dense layout (up to 6 cols) - Used for Collection Detail
                if (width >= 1536) { // 2xl
                    setColumns(6);
                } else if (width >= 1280) { // xl
                    setColumns(5);
                } else if (width >= 1024) { // lg
                    setColumns(4);
                } else if (width >= 768) { // md
                    setColumns(3);
                } else if (width >= 640) { // sm
                    setColumns(2);
                } else {
                    setColumns(1);
                }
            } else {
                // Standard layout (max 3 cols) - Used for Desktop Dashboard (Previous behavior)
                if (width >= 1024) { // lg
                    setColumns(3);
                } else if (width >= 768) { // md
                    setColumns(2);
                } else {
                    setColumns(1);
                }
            }
        };

        updateColumns();
        window.addEventListener("resize", updateColumns);
        return () => window.removeEventListener("resize", updateColumns);
    }, [variant]);

    const childrenArray = React.Children.toArray(children);

    // Create arrays for each column
    const columnWrapper: React.ReactNode[][] = Array.from({ length: columns }, () => []);

    // Distribute children: Child i goes to Column (i % numCols)
    // This creates visual L-to-R sorting (1,2,3 at top) with vertical packing
    childrenArray.forEach((child, i) => {
        columnWrapper[i % columns].push(child);
    });

    return (
        <div className={`flex ${gap} ${className}`}>
            {columnWrapper.map((colChildren, colIndex) => (
                <div key={colIndex} className={`flex flex-col flex-1 ${gap}`}>
                    {/* 
                       gap-6 matches standard gap, but we might want to pass it dynamically.
                       The props 'gap' usually contains space-y logic or gap class. 
                       Here we use flex gap for the vertical spacing inside columns.
                    */}
                    {colChildren.map((child, childIndex) => (
                        <div key={childIndex}>
                            {child}
                        </div>
                    ))}
                </div>
            ))}
        </div>
    );
}
