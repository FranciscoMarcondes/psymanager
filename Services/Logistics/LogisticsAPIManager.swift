import Foundation

/// LogisticsAPIManager — Wrapper for logistics endpoints
class LogisticsAPIManager {
    static let shared = LogisticsAPIManager()
    
    private let baseURL = UserDefaults.standard.string(forKey: "webaiServiceURL") ?? "http://localhost:3000"
    
    // MARK: - Models
    
    struct AddressRouteRequest: Codable {
        let fromAddress: String
        let toAddress: String
    }
    
    struct AddressRouteResponse: Codable {
        let oneWayDistanceKm: Double
        let oneWayHours: Double
        let distanceKm: Double
        let estimatedHours: Double
        let source: String
    }
    
    struct TollEstimateRequest: Codable {
        let fromState: String
        let toState: String
        let oneWayDistanceKm: Double
        let tripType: String // "one-way" or "round-trip"
    }
    
    struct TollEstimateResponse: Codable {
        let estimate: Double
        let rationale: String
        let source: String
    }
    
    struct LogisticsCompleteEstimate {
        let distance: AddressRouteResponse
        let tolls: TollEstimateResponse
        let fuelCost: Double
        let totalCost: Double
        let totalHours: Double
        let recommendedMode: String // "road" or "flight"
    }
    
    // MARK: - API Calls
    
    /// Get route distance and time between two addresses
    func estimateRoute(
        from fromAddress: String,
        to toAddress: String
    ) async throws -> AddressRouteResponse {
        let request = AddressRouteRequest(
            fromAddress: fromAddress,
            toAddress: toAddress
        )
        
        let url = URL(string: "\(baseURL)/api/logistics/estimate")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "logistics", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to estimate route"])
        }
        
        return try JSONDecoder().decode(AddressRouteResponse.self, from: data)
    }
    
    /// Get toll cost estimate between states
    func estimateTolls(
        fromState: String,
        toState: String,
        distanceKm: Double,
        isRoundTrip: Bool = true
    ) async throws -> TollEstimateResponse {
        let request = TollEstimateRequest(
            fromState: fromState,
            toState: toState,
            oneWayDistanceKm: distanceKm,
            tripType: isRoundTrip ? "round-trip" : "one-way"
        )
        
        let url = URL(string: "\(baseURL)/api/logistics/toll-estimate")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "logistics", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to estimate tolls"])
        }
        
        return try JSONDecoder().decode(TollEstimateResponse.self, from: data)
    }
    
    /// Complete logistics estimate: route + tolls + fuel
    func completeEstimate(
        fromCity: String,
        fromState: String,
        toCity: String,
        toState: String,
        fuelPricePerLiter: Double = 5.50, // Default Brazilian fuel price
        vehicleKmPerLiter: Double = 7.5   // Default efficiency
    ) async throws -> LogisticsCompleteEstimate {
        // Build full addresses
        let fromAddress = "\(fromCity), \(fromState)"
        let toAddress = "\(toCity), \(toState)"
        
        // Get route
        let route = try await estimateRoute(from: fromAddress, to: toAddress)
        
        // Get tolls
        let tolls = try await estimateTolls(
            fromState: fromState,
            toState: toState,
            distanceKm: route.oneWayDistanceKm,
            isRoundTrip: true
        )
        
        // Calculate fuel cost
        let fuelLiters = route.distanceKm / vehicleKmPerLiter
        let fuelCost = fuelLiters * fuelPricePerLiter
        
        // Total cost
        let totalCost = fuelCost + tolls.estimate
        
        // Recommend mode
        let recommendedMode = recommendTransportMode(
            totalRoadCost: totalCost,
            distanceKm: route.distanceKm,
            hoursRequired: route.estimatedHours
        )
        
        return LogisticsCompleteEstimate(
            distance: route,
            tolls: tolls,
            fuelCost: fuelCost,
            totalCost: totalCost,
            totalHours: route.estimatedHours,
            recommendedMode: recommendedMode
        )
    }
    
    // MARK: - Private Helpers
    
    private func recommendTransportMode(
        totalRoadCost: Double,
        distanceKm: Double,
        hoursRequired: Double
    ) -> String {
        // Rough flight cost estimation
        let flightEstimate = (distanceKm / 100) * 2.0 // ~R$2 per km
        let isLongDistance = distanceKm > 500
        let isLongDuration = hoursRequired > 8
        
        if flightEstimate <= totalRoadCost * 1.2 && (isLongDistance || isLongDuration) {
            return "flight"
        }
        return "road"
    }
}
