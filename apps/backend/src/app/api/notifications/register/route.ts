import { prisma } from "@/lib/prisma";
import { type NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const registerSchema = z.object({
    deviceToken: z.string().min(1),
    timezone: z.string().optional().default("UTC"),
    enabled: z.boolean(),
    scheduleType: z.enum(["preset", "custom"]),
    presetValue: z.string().optional().nullable(),
    customTime: z.object({
        hour: z.number(),
        minute: z.number(),
    }).optional().nullable(),
});

export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const parsed = registerSchema.safeParse(body);

        if (!parsed.success) {
            return NextResponse.json({ error: parsed.error.issues }, { status: 400 });
        }

        const { deviceToken, timezone, enabled, presetValue, customTime } = parsed.data;

        // Handle Unsubscribe / Disable
        if (!enabled) {
            await prisma.deviceToken.deleteMany({
                where: { token: deviceToken },
            });
            return NextResponse.json({ success: true, message: "Token removed" });
        }

        // Determine Schedule (Hour)
        let scheduleHour = 9;

        if (presetValue) {
            // Format "HH:mm"
            const [h] = presetValue.split(":");
            if (h) scheduleHour = parseInt(h, 10);
        } else if (customTime) {
            scheduleHour = customTime.hour;
        }

        // Upsert
        const result = await prisma.deviceToken.upsert({
            where: { token: deviceToken },
            update: { schedule: scheduleHour, timezone },
            create: { token: deviceToken, schedule: scheduleHour, timezone },
        });

        return NextResponse.json({ success: true, data: result });
    } catch (error) {
        console.error("Failed to register device token:", error);
        return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
}
