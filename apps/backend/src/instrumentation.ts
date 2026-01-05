export async function register() {
    console.log("----------------------------------------------------------------");
    console.log("Server starting...");
    console.log("NODE_ENV:", process.env.NODE_ENV);
    console.log("DATABASE_URL exists:", !!process.env.DATABASE_URL);
    console.log("AUTH_SECRET exists:", !!process.env.AUTH_SECRET);
    console.log("NEXTAUTH_URL exists:", !!process.env.NEXTAUTH_URL);
    console.log("UPLOADTHING_TOKEN exists:", !!process.env.UPLOADTHING_TOKEN);
    console.log("----------------------------------------------------------------");
}
