"use server";

import { GoogleGenerativeAI } from "@google/generative-ai";

import OpenAI from "openai";

const apiKey = process.env.GOOGLE_API_KEY;
const genAI = new GoogleGenerativeAI(apiKey || "");

export async function analyzeImage(imageUrl: string) {
    const provider = process.env.AI_PROVIDER || "GEMINI";

    if (provider === "GEMINI" && !apiKey) {
        throw new Error("GOOGLE_API_KEY is not set");
    }
    if (provider === "OPENAI" && !process.env.OPENAI_API_KEY) {
        throw new Error("OPENAI_API_KEY is not set");
    }

    try {
        // 1. Fetch the image
        // Optimization: If it's a Cloudinary URL, request a smaller/compressed version to save bandwidth/time
        let fetchUrl = imageUrl;
        if (imageUrl.includes("cloudinary.com")) {
            // Insert transformations after /upload/
            // Match the Admin Grid transformation to reuse cache/transformations
            // Grid uses: w_1200,q_auto,f_auto (from src/lib/cloudinary.ts)
            fetchUrl = imageUrl.replace("/upload/", "/upload/w_1200,q_auto,f_auto/");
        } else if (imageUrl.includes("imagedelivery.net")) {
            // Cloudflare Images optimization
            // If the URL is pointing to the 'full' variant, swap it for 'public' (1366px)
            // This allows the AI to analyze a smaller, faster loading image while preserving the full res for users.
            // URL format: https://imagedelivery.net/<HASH>/<ID>/<VARIANT>
            fetchUrl = imageUrl.replace("/full", "/public");
        }

        const response = await fetch(fetchUrl);
        if (!response.ok) throw new Error("Failed to fetch image");
        const arrayBuffer = await response.arrayBuffer();
        const base64Data = Buffer.from(arrayBuffer).toString("base64");
        const mimeType = response.headers.get("content-type") || "image/jpeg";

        const prompt = `
      Analyze this image. First, determine if it is "Fine Art" (human-made masterpiece) or "AI Generated" (digital art, midjourney, etc).
      
      Return a STRICT valid JSON object with these fields:
      - type (string): "Fine Art" or "AI"
      - title (string): The title of the artwork. for AI, generate a creative title.
      - description (string): Short interesting facts about the piece.
      
      IF type is "Fine Art", also include:
      - artist (string): Name of the artist.
      - creationDate (string): Year or period (e.g. "1889").
      - genre (string): e.g. "Landscape", "Portrait".
      - movement (string): e.g. "Impressionism".
      - dominantColors (array of strings): 3-5 hex codes.
      - tags (array of strings): 5-7 keywords.

      IF type is "AI", keep other fields empty or null.
    `;

        let resultText = "";

        if (provider === "OPENAI") {
            const openai = new OpenAI();
            const completion = await openai.chat.completions.create({
                model: "gpt-5-nano-2025-08-07",
                messages: [
                    {
                        role: "user",
                        content: [
                            { type: "text", text: prompt },
                            {
                                type: "image_url",
                                image_url: {
                                    url: `data:${mimeType};base64,${base64Data}`
                                }
                            }
                        ]
                    }
                ],
                response_format: { type: "json_object" }
            });
            resultText = completion.choices[0].message.content || "{}";
        } else {
            // GEMINI (Default)
            // model: gemini-3-flash-preview (User requested "Gemini 3 Flash", preview version found)
            const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

            const imagePart = {
                inlineData: {
                    data: base64Data,
                    mimeType: mimeType,
                },
            };

            const result = await model.generateContent([prompt, imagePart]);
            resultText = result.response.text();
        }

        // Clean up markdown code blocks if present (Gemini sometimes adds them even with JSON mode, OpenAI usually respects response_format but cleanup is safe)
        const cleanJson = resultText.replace(/```json/g, "").replace(/```/g, "").trim();

        const data = JSON.parse(cleanJson);

        // Normalize response
        return {
            ...data,
            channel: data.type === "AI" ? "AI" : "HUMAN"
        };

    } catch (error: any) {
        console.error("AI Analysis Failed:", error);
        // Return the actual error message to the client for debugging
        throw new Error(error.message || "Failed to analyze image");
    }
}

export async function analyzeTitle(title: string) {
    const provider = process.env.AI_PROVIDER || "GEMINI";

    if (provider === "GEMINI" && !apiKey) throw new Error("GOOGLE_API_KEY is not set");
    if (provider === "OPENAI" && !process.env.OPENAI_API_KEY) throw new Error("OPENAI_API_KEY is not set");

    const prompt = `
      You are an art expert. Provide metadata for the artwork titled "${title}".
      
      Return a STRICT valid JSON object with these fields:
      - title (string): Correct full title if needed (e.g. "The Starry Night").
      - description (string): Short interesting facts about the piece.
      - artist (string): Name of the artist.
      - creationDate (string): Year or period (e.g. "1889").
      - genre (string): e.g. "Landscape", "Portrait".
      - movement (string): e.g. "Impressionism".
      - dominantColors (array of strings): 3-5 hex codes typical for this painting.
      - tags (array of strings): 5-7 keywords.

      If the artwork is unknown or generic, generate plausible artistic metadata or return minimal info.
    `;

    try {
        let resultText = "";

        if (provider === "OPENAI") {
            const openai = new OpenAI();
            const completion = await openai.chat.completions.create({
                model: "gpt-5-nano-2025-08-07",
                messages: [{ role: "user", content: prompt }],
                response_format: { type: "json_object" }
            });
            resultText = completion.choices[0].message.content || "{}";
        } else {
            // GEMINI
            const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });
            const result = await model.generateContent(prompt);
            resultText = result.response.text();
        }

        const cleanJson = resultText.replace(/```json/g, "").replace(/```/g, "").trim();
        const data = JSON.parse(cleanJson);

        return {
            ...data,
            channel: "HUMAN" // Assume title search implies existing fine art
        };

    } catch (error: any) {
        console.error("AI Title Analysis Failed:", error);
        throw new Error(error.message || "Failed to analyze title");
    }
}
