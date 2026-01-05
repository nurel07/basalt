
/**
 * Injects Cloudinary optimization parameters into a URL.
 * Defaults to: w_1200, q_auto, f_auto for grid display (HD for Retina).
 * 
 * @param url The original Cloudinary URL
 * @param width Target width, defaults to 1200
 */
export function getOptimizedUrl(url: string, width: number = 1200): string {
    if (!url.includes("/upload/")) return url;

    // Split at /upload/
    const parts = url.split("/upload/");
    const prefix = parts[0] + "/upload";
    const suffix = parts[1];

    // params: width 500, quality auto, format auto (webp/avif)
    const params = `w_${width},q_auto,f_auto`;

    return `${prefix}/${params}/${suffix}`;
}
