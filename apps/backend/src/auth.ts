import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";

export const { handlers, signIn, signOut, auth } = NextAuth({
    providers: [
        Credentials({
            credentials: {
                password: { label: "Password", type: "password" },
            },
            authorize: async (credentials) => {
                console.log("Authorize called");
                const adminPassword = process.env.ADMIN_PASSWORD;
                console.log("ADMIN_PASSWORD set:", !!adminPassword);

                if (!adminPassword) {
                    console.error("ADMIN_PASSWORD is not set in environment variables");
                    return null;
                }

                if (credentials?.password === adminPassword) {
                    console.log("Password match");
                    return { id: "1", name: "Admin" };
                }
                console.log("Password mismatch");
                return null;
            },
        }),
    ],
    pages: {
        signIn: "/login",
    },
    callbacks: {
        jwt({ token, user }) {
            if (user) {
                token.id = user.id;
                token.name = user.name;
            }
            return token;
        },
        session({ session, token }) {
            if (session.user) {
                session.user.name = token.name;
            }
            return session;
        },
    },
    trustHost: true,
});
