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

        const takenDates = wallpapers
            .map((w) => w.releaseDate)
            .filter((date): date is Date => date !== null)
            .map((date) => startOfDay(date));

        // Start looking from tomorrow
        let checkDate = addDays(startOfDay(new Date()), 1);

        // Find the first gap
        while (true) {
            const isTaken = takenDates.some((takenDate) => isSameDay(takenDate, checkDate));

            if (!isTaken) {
                // Found a gap!
                return NextResponse.json({
                    date: format(checkDate, "yyyy-MM-dd")
                });
            }

            checkDate = addDays(checkDate, 1);
        }

    } catch (error) {
        console.error("Error calculating next date:", error);
        return NextResponse.json({ error: "Error calculating next date" }, { status: 500 });
    }
}
