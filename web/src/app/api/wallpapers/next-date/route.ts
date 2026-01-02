import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { addDays, format, startOfDay, isSameDay } from "date-fns";

export async function GET(request: Request) {
    try {
        const { searchParams } = new URL(request.url);
        const channel = searchParams.get("channel");

        // Build where clause
        const whereClause: any = {
            releaseDate: {
                gte: new Date(), // Only look at today and future
            },
        };

        if (channel) {
            whereClause.channel = channel;
        }

        // Get all future release dates
        const wallpapers = await prisma.wallpaper.findMany({
            where: whereClause,
            select: {
                releaseDate: true,
            },
            orderBy: {
                releaseDate: "asc",
            },
        });

        // Debug Log
        console.log(`[NextDate] Found ${wallpapers.length} future wallpapers for channel: ${channel || 'ALL'}`);
        // Log first few dates
        const firstFew = wallpapers.slice(0, 5).map(w => w.releaseDate?.toISOString());
        console.log(`[NextDate] Starts with: ${firstFew.join(', ')}`);

        const takenDateStrings = new Set(
            wallpapers
                .map((w) => w.releaseDate)
                .filter((date): date is Date => date !== null)
                .map((date) => format(date, "yyyy-MM-dd"))
        );

        // Start looking from tomorrow
        let checkDate = addDays(startOfDay(new Date()), 1);

        // Find the first gap
        for (let i = 0; i < 730; i++) { // Limit to 2 years to prevent infinite loops safety
            const checkString = format(checkDate, "yyyy-MM-dd");
            const isTaken = takenDateStrings.has(checkString);

            if (!isTaken) {
                console.log(`[NextDate] Found gap: ${checkString}`);
                return NextResponse.json({
                    date: checkString
                });
            }

            checkDate = addDays(checkDate, 1);
        }

        // Fallback
        return NextResponse.json({ date: format(addDays(new Date(), 1), "yyyy-MM-dd") });

    } catch (error) {
        console.error("Error calculating next date:", error);
        return NextResponse.json({ error: "Error calculating next date" }, { status: 500 });
    }
}
