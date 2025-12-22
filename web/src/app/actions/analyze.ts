"use server";

import { GoogleGenerativeAI } from "@google/generative-ai";

const apiKey = process.env.GOOGLE_API_KEY;
const genAI = new GoogleGenerativeAI(apiKey || "");

export async function analyzeImage(imageUrl: string) {
    if (!apiKey) {
        throw new Error("GOOGLE_API_KEY is not set");
    }

    try {
        // 1. Fetch the image
        const response = await fetch(imageUrl);
        if (!response.ok) throw new Error("Failed to fetch image");
        const arrayBuffer = await response.arrayBuffer();

        // 2. Prepare for Gemini
        // model: gemini-3.0-flash (User requested "Gemini 3 Flash")
        const model = genAI.getGenerativeModel({ model: "gemini-3.0-flash" });

        const prompt = `
      Analyze this fine art wallpaper. 
      Return a STRICT valid JSON object (no markdown formatting, no backticks) with these fields:
      - title (string): The name of the artwork (or a creative one if unknown).
      - artist (string): The name of the artist (or "Unknown").
      - date (string): Year or timeframe (e.g. "1923" or "19th Century").
      - description (string): A compelling 1-2 sentence description suitable for a wallpaper app.
      - tags (array of strings): 5-7 keywords describing the style, subject, and mood.
    `;

        const imagePart = {
            inlineData: {
                data: Buffer.from(arrayBuffer).toString("base64"),
                mimeType: response.headers.get("content-type") || "image/jpeg",
            },
        };

        const result = await model.generateContent([prompt, imagePart]);
        const text = result.response.text();

        // Clean up markdown code blocks if present
        const cleanJson = text.replace(/```json/g, "").replace(/```/g, "").trim();

        return JSON.parse(cleanJson);

    } catch (error) {
        console.error("AI Analysis Failed:", error);
        throw new Error("Failed to analyze image");
    }
}
