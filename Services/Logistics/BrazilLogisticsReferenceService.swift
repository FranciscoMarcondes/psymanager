import Foundation

struct BrazilFuelReference {
    let state: String
    let gasolinePrice: Double
    let sourceLabel: String
}

enum BrazilLogisticsReferenceService {
    private static let averageGasolineByState: [String: Double] = [
        "SP": 5.89,
        "RJ": 6.14,
        "MG": 5.97,
        "PR": 5.95,
        "RS": 6.08,
        "SC": 5.92,
        "BA": 6.22,
        "PE": 6.11,
        "CE": 6.18,
        "DF": 5.86,
        "GO": 5.88,
        "AM": 6.79,
    ]

    static func fuelReference(for state: String) -> BrazilFuelReference? {
        let normalized = state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let price = averageGasolineByState[normalized] else { return nil }
        return BrazilFuelReference(
            state: normalized,
            gasolinePrice: price,
            sourceLabel: "Referencia Brasil"
        )
    }

    static func suggestedTollCost(
        originState: String,
        destinationState: String,
        distanceKm: Double
    ) -> Double {
        let normalizedOrigin = originState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedDestination = destinationState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if normalizedOrigin == normalizedDestination {
            return max(0, distanceKm * intraStateMultiplier(for: normalizedOrigin))
        }

        return max(0, distanceKm * interStateMultiplier(origin: normalizedOrigin, destination: normalizedDestination))
    }

    static func tollSourceLabel(originState: String, destinationState: String) -> String {
        let normalizedOrigin = originState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedDestination = destinationState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalizedOrigin == normalizedDestination {
            return "Referencia Brasil por UF"
        }
        return "Referencia Brasil por rota"
    }

    private static func intraStateMultiplier(for state: String) -> Double {
        switch state {
        case "SP", "RJ", "PR", "SC", "RS":
            return 0.17
        case "MG", "DF", "GO":
            return 0.10
        case "BA", "PE", "CE":
            return 0.08
        default:
            return 0.05
        }
    }

    private static func interStateMultiplier(origin: String, destination: String) -> Double {
        let denseCorridorStates: Set<String> = ["SP", "RJ", "PR", "SC", "RS", "MG"]
        if denseCorridorStates.contains(origin) || denseCorridorStates.contains(destination) {
            return 0.18
        }

        let northeastStates: Set<String> = ["BA", "PE", "CE"]
        if northeastStates.contains(origin) || northeastStates.contains(destination) {
            return 0.09
        }

        if origin == "AM" || destination == "AM" {
            return 0.03
        }

        return 0.07
    }
}
