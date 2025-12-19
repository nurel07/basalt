
/**
 * Injects Cloudinary optimization parameters into a URL.
 * Defaults to: w_500, q_auto, f_auto for grid display.
 * 
 * @param url The original Cloudinary URL
 * @param width Target width, defaults to 500
 */
export function getOptimizedUrl(url: string, width: number = 500): string {
    if (!url.includes("/upload/")) return url;

    // Split at /upload/
    const parts = url.split("/upload/");
    const prefix = parts[0] + "/upload";
    const suffix = parts[1];

    // params: width 500, quality auto, format auto (webp/avif)
    const params = `w_${width},q_auto,f_auto`;

    return `${prefix}/${params}/${suffix}`;
}
