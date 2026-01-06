import Foundation

struct Collection: Identifiable, Decodable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let coverImage: String
    let wallpaperCount: Int
    let wallpapers: [Wallpaper]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case description
        case coverImage
        case count = "_count"
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
        wallpapers = try container.decodeIfPresent([Wallpaper].self, forKey: .wallpapers)
        
        // Handle _count: { wallpapers: Int }
        if let countContainer = try? container.nestedContainer(keyedBy: CountKeys.self, forKey: .count) {
            wallpaperCount = try countContainer.decode(Int.self, forKey: .wallpapers)
        } else {
            wallpaperCount = 0
        }
    }
    
    // Helper enum for the nested count object
    enum CountKeys: String, CodingKey {
        case wallpapers
    }
}
