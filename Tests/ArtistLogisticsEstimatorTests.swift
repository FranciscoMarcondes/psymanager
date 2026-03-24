import XCTest
@testable import PsyManager

final class ArtistLogisticsEstimatorTests: XCTestCase {
    func testSameStateReturnsOnlyRoadEstimate() {
        let estimate = ArtistLogisticsEstimator.estimate(
            originCity: "Sao Paulo",
            originState: "SP",
            destinationCity: "Campinas",
            destinationState: "SP",
            eventDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
            returnDate: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
            vehicleKmPerLiter: 10,
            fuelPricePerLiter: 6,
            tollCost: 40,
            extraRoadCosts: 20
        )

        XCTAssertNil(estimate.flight)
        XCTAssertGreaterThan(estimate.road.totalRoadCost, 0)
        XCTAssertEqual(estimate.recommendedMode, "Rodoviário")
    }

    func testDifferentStateIncludesFlightEstimateAndAirports() {
        let estimate = ArtistLogisticsEstimator.estimate(
            originCity: "Sao Paulo",
            originState: "SP",
            destinationCity: "Rio de Janeiro",
            destinationState: "RJ",
            eventDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date(),
            returnDate: Calendar.current.date(byAdding: .day, value: 11, to: Date()) ?? Date(),
            vehicleKmPerLiter: 10,
            fuelPricePerLiter: 6,
            tollCost: 120,
            extraRoadCosts: 50
        )

        XCTAssertNotNil(estimate.flight)
        XCTAssertGreaterThan(estimate.flight?.totalAirCost ?? 0, 0)

        let airports = ArtistLogisticsEstimator.airportOptions(for: "RJ")
        XCTAssertFalse(airports.isEmpty)
    }
}
