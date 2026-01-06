import { NextResponse } from "next/server";
import { auth } from "@/auth";

export async function POST(request: Request) {
    const session = await auth();
    if (!session) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    const apiToken = process.env.CLOUDFLARE_API_TOKEN;

    if (!accountId || !apiToken) {
        return NextResponse.json({ error: "Missing Cloudflare credentials" }, { status: 500 });
    }

    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v2/direct_upload`;

    try {
        const formData = new FormData();
        // We can request a signed URL if we want to restrict access, 
        // but for public wallpapers, signed URLs might complicate things unless we serve variants.
        // Default is usually fine for this use case if we want them public.
        // formData.append("requireSignedURLs", "false"); 

        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${apiToken}`,
            },
            body: formData
        });

        const data = await response.json();

        if (!data.success) {
            throw new Error(data.errors?.[0]?.message || "Failed to get upload URL");
        }

        return NextResponse.json({
            uploadUrl: data.result.uploadURL,
            id: data.result.id
        });

    } catch (error: any) {
        console.error("Cloudflare upload error:", error);
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
