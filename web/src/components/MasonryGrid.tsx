import React from "react";

interface MasonryGridProps {
    children: React.ReactNode;
    className?: string;
}

export default function MasonryGrid({ children, className = "" }: MasonryGridProps) {
    return (
        <div className={`columns-1 md:columns-2 lg:columns-3 gap-6 space-y-6 ${className}`}>
            {/* 
              We use 'break-inside-avoid' on children to prevent them from being split across columns.
              However, since we can't enforce styles on children directly here easily without cloning,
              we rely on the consumer to wrap children or ensure they have 'break-inside-avoid'.
              Alternatively, we can wrap each child in a div with that class.
            */}
            {React.Children.map(children, (child) => (
                <div className="break-inside-avoid mb-6">
                    {child}
                </div>
            ))}
        </div>
    );
}
