import Foundation
import CoreLocation

// MARK: - Nominatim Geocoding Service
actor NominatimGeocodingService {
    private static let nominatimBase = "https://nominatim.openstreetmap.org"
    private static let userAgent = "PsyManager-iOS/1.0"
    
    enum GeoError: LocalizedError {
        case invalidLocation
        case networkError
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .invalidLocation: return "Localização inválida"
            case .networkError: return "Erro ao conectar com OpenStreetMap"
            case .notFound: return "Local não encontrado"
            }
        }
    }
    
    struct LocationCoordinate: Codable {
        let lat: String
        let lon: String
        let displayName: String
        
        enum CodingKeys: String, CodingKey {
            case lat, lon
            case displayName = "display_name"
        }
    }
    
    struct RouteInfo {
        let distance: Double // in km
        let duration: Int    // in minutes
        let route: String    // "City1 → City2"
        let estimatedToll: Double? // in BRL
    }
    
    // MARK: - Geocoding (City → Coordinates)
    
    /// Geocode a city name to coordinates
    func geocode(city: String, state: String = "") async throws -> LocationCoordinate {
        let query = state.isEmpty ? city : "\(city), \(state), Brazil"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "\(Self.nominatimBase)/search?q=\(encodedQuery)&format=json&limit=1") else {
            throw GeoError.invalidLocation
        }
        
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw GeoError.networkError
            }
            
            let results = try JSONDecoder().decode([LocationCoordinate].self, from: data)
            guard let first = results.first else { throw GeoError.notFound }
            return first
        } catch is DecodingError {
            throw GeoError.notFound
        }
    }
    
    // MARK: - Distance Calculation
    
    /// Calculate distance and duration between two points (Haversine formula)
    func calculateDistance(
        from: (lat: Double, lon: Double),
        to: (lat: Double, lon: Double)
    ) -> RouteInfo {
        let distance = haversineDistance(lat1: from.lat, lon1: from.lon, lat2: to.lat, lon2: to.lon)
        let duration = Int(distance / 100 * 60) // rough estimate: 100km/h average
        
        // Estimate toll for Brazilian highways (rough: R$ 0.50 per km for major routes)
        let toll = distance > 100 ? distance * 0.50 : nil
        
        return RouteInfo(
            distance: distance,
            duration: duration,
            route: "Rota calculada (\(Int(distance))km)",
            estimatedToll: toll
        )
    }
    
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0 // Earth radius in km
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
    
    // MARK: - Full Route Planning
    
    /// Get detailed route between two cities
    func planRoute(fromCity: String, fromState: String, toCity: String, toState: String) async throws -> RouteInfo {
        let fromCoord = try await geocode(city: fromCity, state: fromState)
        let toCoord = try await geocode(city: toCity, state: toState)
        
        let fromLat = Double(fromCoord.lat) ?? 0
        let fromLon = Double(fromCoord.lon) ?? 0
        let toLat = Double(toCoord.lat) ?? 0
        let toLon = Double(toCoord.lon) ?? 0
        
        return calculateDistance(
            from: (fromLat, fromLon),
            to: (toLat, toLon)
        )
    }
}
