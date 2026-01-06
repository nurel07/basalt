import Foundation

struct Wallpaper: Identifiable, Decodable {
    let id: String
    let url: String
    let name: String?
    let description: String?
    let artist: String?
    let creationDate: String?
    let collectionOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id, url, name, description, artist, creationDate, collectionOrder
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
    }
}
