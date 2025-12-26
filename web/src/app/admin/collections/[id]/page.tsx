import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import CollectionDetailClient from "@/components/CollectionDetailClient";

export default async function CollectionDetailPage({
    params,
}: {
    params: Promise<{ id: string }>;
}) {
    const { id } = await params;
    const collection = await prisma.mobileCollection.findUnique({
        where: { id },
        include: {
            wallpapers: {
                orderBy: { createdAt: "desc" },
            },
        },
    });

    if (!collection) {
        notFound();
    }

    return (
        <CollectionDetailClient
            collection={collection}
            wallpapers={collection.wallpapers as any}
        />
    );
}
