import Foundation

struct Collection: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let coverImage: String
    let wallpaperCount: Int
    let order: Int
    let channel: String?
    let wallpapers: [Wallpaper]?
    
    // Explicit memberwise initializer to be used alongside custom decodable init
    init(id: String, name: String, slug: String, description: String?, coverImage: String, wallpaperCount: Int, order: Int, channel: String?, wallpapers: [Wallpaper]?) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.coverImage = coverImage
        self.wallpaperCount = wallpaperCount
        self.order = order
        self.channel = channel
        self.wallpapers = wallpapers
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case description
        case coverImage
        case count = "_count"
        case order
        case channel
        case wallpapers
    }
    
    // Custom decoding to handle the nested _count object from Prisma/Backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverImage = try container.decode(String.self, forKey: .coverImage)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        channel = try container.decodeIfPresent(String.self, forKey: .channel)
        wallpapers = try container.decodeIfPresent([Wallpaper].self, forKey: .wallpapers)
        
        // Handle _count: { wallpapers: Int }
        // Note: The list endpoint returns _count, but the detail endpoint returns wallpapers array instead
        if let countContainer = try? container.nestedContainer(keyedBy: CountKeys.self, forKey: .count) {
            wallpaperCount = try countContainer.decode(Int.self, forKey: .wallpapers)
        } else if let decodedWallpapers = wallpapers {
            // Fallback: use actual wallpapers array count when _count is not present
            wallpaperCount = decodedWallpapers.count
        } else {
            wallpaperCount = 0
        }
    }
    
    // Helper enum for the nested count object
    enum CountKeys: String, CodingKey {
        case wallpapers
    }
}
