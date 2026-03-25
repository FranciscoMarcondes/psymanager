import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Event Geocoding Integration
/// Enriches RadarEvents with real coordinates from Nominatim
/// Integrates location-based features (distance calculation, route planning)

struct EventGeocodingIntegration {
    private let geocodingService = NominatimGeocodingService()
    
    // MARK: - Event Enrichment
    
    /// Geocode a RadarEvent and return enriched version with coordinates
    func enrichEventWithCoordinates(_ event: RadarEvent) async -> EnrichedRadarEvent {
        do {
            let coordinate = try await geocodingService.geocode(city: event.city, state: event.state)
            let lat = Double(coordinate.lat) ?? 0
            let lon = Double(coordinate.lon) ?? 0
            
            return EnrichedRadarEvent(
                event: event,
                latitude: lat,
                longitude: lon,
                displayLocation: coordinate.displayName,
                isGeocodified: true
            )
        } catch {
            // Return event without coordinates if geocoding fails
            return EnrichedRadarEvent(
                event: event,
                latitude: nil,
                longitude: nil,
                displayLocation: "\(event.city), \(event.state)",
                isGeocodified: false,
                geocodingError: error.localizedDescription
            )
        }
    }
    
    /// Batch geocode multiple events
    func enrichEventsWithCoordinates(_ events: [RadarEvent]) async -> [EnrichedRadarEvent] {
        var enriched: [EnrichedRadarEvent] = []
        
        for event in events {
            let enrichedEvent = await enrichEventWithCoordinates(event)
            enriched.append(enrichedEvent)
            
            // Respect Nominatim rate limit: 1 request per second
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        return enriched
    }
    
    // MARK: - Distance & Routing
    
    /// Calculate distance from artist location to event
    /// Used for logistics planning (fuel cost, travel time)
    func calculateDistanceToEvent(
        fromCity: String,
        fromState: String,
        toEvent: EnrichedRadarEvent
    ) async -> DistanceResult? {
        guard let eventLat = toEvent.latitude, let eventLon = toEvent.longitude else {
            return nil
        }
        
        do {
            let fromCoord = try await geocodingService.geocode(city: fromCity, state: fromState)
            let fromLat = Double(fromCoord.lat) ?? 0
            let fromLon = Double(fromCoord.lon) ?? 0
            
            let route = await geocodingService.calculateDistance(
                from: (fromLat, fromLon),
                to: (eventLat, eventLon)
            )
            
            return DistanceResult(
                distanceKm: route.distance,
                durationMinutes: route.duration,
                estimatedFuelCostBRL: route.distance * 0.35, // ~R$ 0.35/km average
                estimatedTollBRL: route.estimatedToll ?? 0,
                routeDescription: route.route
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - Location Suggestions
    
    /// Suggest nearby cities/events based on current event location
    /// Helps discover adjacent opportunities
    func suggestNearbyOpportunities(
        eventLatitude: Double,
        eventLongitude: Double,
        radiusKm: Double = 150
    ) -> [LocationSuggestion] {
        // Mock data: Brazilian psytrance scene hot spots
        let brazilianVenues = [
            (city: "São Paulo", state: "SP", lat: -23.5505, lon: -46.6333, distance: 0),
            (city: "Rio de Janeiro", state: "RJ", lat: -22.9068, lon: -43.1729, distance: 0),
            (city: "Belo Horizonte", state: "MG", lat: -19.9191, lon: -43.9386, distance: 0),
            (city: "Brasília", state: "DF", lat: -15.8267, lon: -47.8617, distance: 0),
            (city: "Curitiba", state: "PR", lat: -25.4284, lon: -49.2733, distance: 0),
            (city: "Salvador", state: "BA", lat: -12.9714, lon: -38.5014, distance: 0),
            (city: "Fortaleza", state: "CE", lat: -3.7319, lon: -38.5267, distance: 0),
            (city: "Recife", state: "PE", lat: -8.0476, lon: -34.8770, distance: 0),
        ]
        
        let suggestions = brazilianVenues.compactMap { venue in
            let dist = haversineDistance(
                lat1: eventLatitude, lon1: eventLongitude,
                lat2: venue.lat, lon2: venue.lon
            )
            
            if dist <= radiusKm {
                return LocationSuggestion(
                    city: venue.city,
                    state: venue.state,
                    distanceKm: dist,
                    latitude: venue.lat,
                    longitude: venue.lon,
                    popularity: calculatePopularity(forCity: venue.city)
                )
            }
            return nil
        }
        
        return suggestions.sorted { $0.distanceKm < $1.distanceKm }
    }
    
    private func calculatePopularity(forCity city: String) -> Int {
        // Rough psytrance scene popularity by city
        let popularity: [String: Int] = [
            "São Paulo": 5,
            "Rio de Janeiro": 5,
            "Belo Horizonte": 4,
            "Brasília": 3,
            "Curitiba": 3,
            "Salvador": 3,
            "Fortaleza": 2,
            "Recife": 2,
        ]
        return popularity[city] ?? 1
    }
    
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

// MARK: - Data Models

struct EnrichedRadarEvent: Identifiable {
    let id = UUID()
    let event: RadarEvent
    let latitude: Double?
    let longitude: Double?
    let displayLocation: String
    let isGeocodified: Bool
    var geocodingError: String? = nil
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct DistanceResult {
    let distanceKm: Double
    let durationMinutes: Int
    let estimatedFuelCostBRL: Double
    let estimatedTollBRL: Double
    let routeDescription: String
    
    var totalCostBRL: Double {
        estimatedFuelCostBRL + estimatedTollBRL
    }
}

struct LocationSuggestion: Identifiable {
    let id = UUID()
    let city: String
    let state: String
    let distanceKm: Double
    let latitude: Double
    let longitude: Double
    let popularity: Int // 1-5 scale
    
    var displayName: String {
        "\(city), \(state) (\(Int(distanceKm))km)"
    }
}
