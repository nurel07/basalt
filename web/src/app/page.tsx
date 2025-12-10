import { prisma } from "@/lib/prisma";
import { format } from "date-fns";
import MasonryGrid from "@/components/MasonryGrid";

export const dynamic = "force-dynamic";

export default async function Home() {
  const wallpapers = await prisma.wallpaper.findMany({
    where: {
      releaseDate: {
        lte: new Date(),
      },
    },
    orderBy: {
      releaseDate: "asc",
    },
  });

  return (
    <div className="min-h-screen p-8">
      <h1 className="text-4xl font-bold text-center mb-12">Wallpapers</h1>

      <MasonryGrid>
        {wallpapers.map((wallpaper) => (
          <div
            key={wallpaper.id}
            className="group relative overflow-hidden rounded-xl shadow-lg cursor-pointer break-inside-avoid"
          >
            <img
              src={wallpaper.url}
              alt={wallpaper.description || "Wallpaper"}
              className="w-full h-auto object-cover transition-transform duration-500 group-hover:scale-105"
            />

            <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-end p-6">
              <p className="text-white text-lg font-medium">
                {wallpaper.description}
              </p>
              <p className="text-gray-300 text-sm mt-2">
                {format(wallpaper.releaseDate, "MMMM d, yyyy")}
              </p>
            </div>
          </div>
        ))}
      </MasonryGrid>
    </div>
  );
}
