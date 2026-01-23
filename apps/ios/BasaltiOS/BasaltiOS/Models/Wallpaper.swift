import Foundation

struct Wallpaper: Identifiable, Decodable, Hashable {
    let id: String
    let url: String
    let name: String?
    let description: String?
    let artist: String?
    let creationDate: String?
    let collectionOrder: Int
    let dominantColors: [String]?
    let tags: [String]?
    let genre: String?
    let movement: String?
    let externalUrl: String?
    
    // Explicit memberwise initializer
    init(id: String, url: String, name: String?, description: String?, artist: String?, creationDate: String?, collectionOrder: Int, dominantColors: [String]? = nil, tags: [String]? = nil, genre: String? = nil, movement: String? = nil, externalUrl: String? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.description = description
        self.artist = artist
        self.creationDate = creationDate
        self.collectionOrder = collectionOrder
        self.dominantColors = dominantColors
        self.tags = tags
        self.genre = genre
        self.movement = movement
        self.externalUrl = externalUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case id, url, name, description, artist, creationDate, collectionOrder
        case dominantColors, tags, genre, movement, externalUrl
    }
    
    // Custom decoding to handle optional/missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        creationDate = try container.decodeIfPresent(String.self, forKey: .creationDate)
        collectionOrder = try container.decodeIfPresent(Int.self, forKey: .collectionOrder) ?? 0
        
        dominantColors = try container.decodeIfPresent([String].self, forKey: .dominantColors)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        movement = try container.decodeIfPresent(String.self, forKey: .movement)
        externalUrl = try container.decodeIfPresent(String.self, forKey: .externalUrl)
    }
}
