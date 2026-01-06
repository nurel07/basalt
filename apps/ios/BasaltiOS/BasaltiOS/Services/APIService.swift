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
            throw APIError.serverError
        }
        
        do {
            let collections = try JSONDecoder().decode([Collection].self, from: data)
            return collections
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError
        }
    }
    
    func fetchCollection(id: String) async throws -> Collection {
        guard let url = URL(string: "\(baseUrl)/collections/\(id)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        do {
            let collection = try JSONDecoder().decode(Collection.self, from: data)
            return collection
        } catch {
            print("Decoding error for collection details: \(error)")
            throw APIError.decodingError
        }
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
}
