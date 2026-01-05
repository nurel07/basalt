import { v2 as cloudinary } from "cloudinary";
import { NextResponse } from "next/server";
import { auth } from "@/auth";

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});

export async function POST(request: Request) {
    const session = await auth();
    if (!session) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Default to 'wallpapers' if not specified
    let folder = "wallpapers";
    try {
        const body = await request.json();
        if (body.folder) folder = body.folder;
    } catch (e) {
        // Ignore JSON parse error (empty body)
    }

    const timestamp = Math.round(new Date().getTime() / 1000);
    const signature = cloudinary.utils.api_sign_request(
        {
            timestamp: timestamp,
            folder: folder,
        },
        process.env.CLOUDINARY_API_SECRET!
    );

    return NextResponse.json({
        timestamp,
        signature,
        cloudName: process.env.CLOUDINARY_CLOUD_NAME,
        apiKey: process.env.CLOUDINARY_API_KEY
    });
}
