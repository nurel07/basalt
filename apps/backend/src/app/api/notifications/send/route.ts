import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
// @ts-ignore
import { ApnsClient, Notification } from "apns2";

// Helper to inject Cloudinary optimization params
function optimizeUrl(url: string): string {
    const keyword = "/upload/";
    if (!url.includes(keyword)) return url;
    const params = "w_1248,c_limit,q_auto,f_auto";
    return url.replace(keyword, `${keyword}${params}/`);
}

export async function POST(request: Request) {
    try {
        const authHeader = request.headers.get("authorization");
        if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
            return new NextResponse("Unauthorized", { status: 401 });
        }

        // Check for "force" mode to test immediately
        let force = false;
        try {
            const body = await request.json();
            force = body.force === true;
        } catch (e) {
            // Body might be empty, ignore
        }

        // 1. Get tokens scheduled for the current hour (UTC)
        const currentHour = new Date().getUTCHours();
        const whereClause = force ? {} : { schedule: currentHour };

        const scheduledTokens = await prisma.deviceToken.findMany({
            where: whereClause,
            // In a real app, you might handle timezone offsets here.
            // For simplicity, we assume the schedule is stored in UTC or we just fire based on checking the user's local time vs server time.
            // If 'schedule' is stored as "User's preferred 9 AM", we need to check if it is currently 9 AM in their timezone.
            // However, the schema has `schedule` as Int and `timezone` string.
            // For MVP, Fan-out is complicated with mixed timezones. 
            // Let's assume we find all users where (CurrentUTC + Offset) % 24 == UserSchedule.
            // But verifying logic in SQL is hard. 
            // Let's stick to a simple "Send to everyone who wants it at this UTC hour" or just send to everyone for now if the schedule is just an int.
        },
        });

    // Simplification for MVP: Just fetch ALL tokens if we want to blast, 
    // or fetch matching `schedule` if we assume schedule is UTC.
    // Let's assume schedule is stored as UTC hour for now or we just query purely by the integer.

    if (scheduledTokens.length === 0) {
        return NextResponse.json({ message: "No devices scheduled for this hour" });
    }

    // 2. Fetch Today's Wallpaper
    const wallpaper = await prisma.wallpaper.findFirst({
        where: {
            releaseDate: { lte: new Date() },
            channel: "HUMAN",
        },
        orderBy: [{ releaseDate: "desc" }, { createdAt: "desc" }],
    });

    if (!wallpaper) {
        return NextResponse.json({ message: "No wallpaper found to send" });
    }

    const imageUrl = optimizeUrl(wallpaper.url);

    // 3. Configure APNs
    if (!process.env.APNS_KEY_ID || !process.env.APNS_TEAM_ID || !process.env.APNS_P8) {
        console.error("Missing APNs configuration");
        return NextResponse.json({ error: "Server misconfigured (APNs)" }, { status: 500 });
    }

    const client = new ApnsClient({
        team: process.env.APNS_TEAM_ID,
        keyId: process.env.APNS_KEY_ID,
        signingKey: process.env.APNS_P8.replace(/\\n/g, '\n'), // Handle env var newlines
        defaultTopic: process.env.BUNDLE_ID || "yevgen.glukhov.BasaltiOS", // Use env var for Bundle ID
    });

    // 4. Fan Out
    const notifications = scheduledTokens.map((device) => {
        return new Notification(device.token, {
            alert: {
                title: "New Wallpaper Available",
                body: `Check out today's artwork: ${wallpaper.name || "Untitled"}`,
            },
            badge: 1,
            sound: "default",
            data: {
                image_url: imageUrl, // For Notification Service Extension
                wallpaper_id: wallpaper.id,
            },
            topic: process.env.BUNDLE_ID || "yevgen.glukhov.BasaltiOS",
            mutableContent: true, // Critical for Service Extension
        });
    });

    await client.sendMany(notifications);

    return NextResponse.json({
        success: true,
        sent_count: notifications.length,
        wallpaper: wallpaper.name
    });

} catch (error) {
    console.error("Notification Fan-out Error:", error);
    // @ts-ignore
    return NextResponse.json({ error: error.message || "Internal Error" }, { status: 500 });
}
}
