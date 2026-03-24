import Foundation

struct SavedLogisticsEstimate: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let originLabel: String
    let destinationLabel: String
    let eventDate: Date
    let recommendedMode: String
    let roadTotal: Double
    let airTotal: Double?
    let routeSourceLabel: String
    let pricingSourceLabel: String?
}

enum LogisticsEstimateHistoryStore {
    private static let defaultsKey = "psy.logistics.estimateHistory"
    private static let maxItems = 15

    static func load() -> [SavedLogisticsEstimate] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([SavedLogisticsEstimate].self, from: data)) ?? []
    }

    static func append(
        estimate: LogisticsEstimate,
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String,
        eventDate: Date
    ) {
        let entry = SavedLogisticsEstimate(
            id: UUID(),
            createdAt: Date(),
            originLabel: "\(originCity) - \(originState)",
            destinationLabel: "\(destinationCity) - \(destinationState)",
            eventDate: eventDate,
            recommendedMode: estimate.recommendedMode,
            roadTotal: estimate.road.totalRoadCost,
            airTotal: estimate.flight?.totalAirCost,
            routeSourceLabel: estimate.road.routeSource.label,
            pricingSourceLabel: estimate.flight?.pricingSource.label
        )

        var items = load()
        items.insert(entry, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
