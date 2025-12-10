"use client";

import React, { useEffect, useState } from "react";

interface MasonryGridProps {
    children: React.ReactNode;
    className?: string;
    gap?: string;
}

export default function MasonryGrid({ children, className = "", gap = "gap-6" }: MasonryGridProps) {
    const [columns, setColumns] = useState(1);

    // Responsive breakpoints similar to Tailwind defaults
    // md: 768px -> 2 cols
    // lg: 1024px -> 3 cols
    useEffect(() => {
        const updateColumns = () => {
            if (window.innerWidth >= 1024) {
                setColumns(3);
            } else if (window.innerWidth >= 768) {
                setColumns(2);
            } else {
                setColumns(1);
            }
        };

        updateColumns();
        window.addEventListener("resize", updateColumns);
        return () => window.removeEventListener("resize", updateColumns);
    }, []);

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
                <div key={colIndex} className="flex flex-col flex-1 gap-6">
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
