import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseUrl = "https://basalt-prod.up.railway.app/api"
    
    func fetchCollections() async throws -> [Collection] {
        guard let url = URL(string: "\(baseUrl)/collections") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, url: url.absoluteString)
        }
        
        do {
            let collections = try JSONDecoder().decode([Collection].self, from: data)
            return collections
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError(error)
        }
    }
    
    func fetchCollection(id: String) async throws -> Collection {
        guard let url = URL(string: "\(baseUrl)/collections/\(id)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, url: url.absoluteString)
        }
        
        do {
            let collection = try JSONDecoder().decode(Collection.self, from: data)
            return collection
        } catch {
            print("Decoding error for collection details: \(error)")
            throw APIError.decodingError(error)
        }
    }
    
    func fetchTodayWallpaper() async throws -> Wallpaper {
        guard let url = URL(string: "\(baseUrl)/wallpapers/today") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, url: url.absoluteString)
        }
        
        do {
            let wallpaper = try JSONDecoder().decode(Wallpaper.self, from: data)
            return wallpaper
        } catch {
            print("Decoding error for today wallpaper: \(error)")
            throw APIError.decodingError(error)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int, url: String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let code, let url):
            return "Server Error \(code) accessing \(url)"
        case .decodingError(let error):
            return "Decoding Error: \(error.localizedDescription)"
        }
    }
}
