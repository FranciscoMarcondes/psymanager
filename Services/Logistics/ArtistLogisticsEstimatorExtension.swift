import Foundation

// MARK: - Real-time API Extension
extension ArtistLogisticsEstimator {
    
    static func estimateWithRealTimeData(
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String,
        eventDate: Date,
        returnDate: Date,
        vehicleKmPerLiter: Double,
        fuelPricePerLiter: Double,
        tollCost: Double,
        extraRoadCosts: Double
    ) async -> LogisticsEstimate {
        // Get distance: try API first, fallback to Haversine
        let distanceData = await RealTimeLogisticsResolver.resolveDistance(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState
        ) {
            let localDistance = estimatedRoadDistanceKm(
                originCity: originCity,
                originState: originState,
                destinationCity: destinationCity,
                destinationState: destinationState
            )
            return (localDistance, localDistance / 75.0)
        }

        let road = roadEstimateWithApiData(
            distanceKm: distanceData.distanceKm,
            durationHours: distanceData.durationHours,
            vehicleKmPerLiter: vehicleKmPerLiter,
            fuelPricePerLiter: fuelPricePerLiter,
            tollCost: tollCost,
            extraCosts: extraRoadCosts,
            routeSource: distanceData.source
        )

        let flight = await flightEstimateWithApiData(
            originState: originState,
            destinationState: destinationState,
            eventDate: eventDate,
            returnDate: returnDate,
            roadDistanceKm: road.distanceKm
        )

        let recommendation: (String, String)
        if let flight {
            if flight.totalAirCost <= road.totalRoadCost * 1.15 || road.estimatedTravelHours >= 8 {
                recommendation = (
                    "Aéreo",
                    "A viagem rodoviária ficou longa/cansativa ou com custo próximo ao aéreo."
                )
            } else {
                recommendation = (
                    "Rodoviário",
                    "O deslocamento por estrada está com melhor custo total para este evento."
                )
            }
        } else {
            recommendation = (
                "Rodoviário",
                "Mesmo estado: cálculo aéreo não foi priorizado; estrada tende a ser mais eficiente."
            )
        }

        return LogisticsEstimate(
            road: road,
            flight: flight,
            recommendedMode: recommendation.0,
            recommendationReason: recommendation.1
        )
    }

    private static func roadEstimateWithApiData(
        distanceKm: Double,
        durationHours: Double,
        vehicleKmPerLiter: Double,
        fuelPricePerLiter: Double,
        tollCost: Double,
        extraCosts: Double,
        routeSource: LogisticsDataSource
    ) -> RoadEstimate {
        let kmPerLiter = max(vehicleKmPerLiter, 1)
        let liters = distanceKm / kmPerLiter
        let fuelCost = liters * max(fuelPricePerLiter, 0)
        let total = fuelCost + max(tollCost, 0) + max(extraCosts, 0)

        return RoadEstimate(
            distanceKm: distanceKm,
            fuelLiters: liters,
            fuelCost: fuelCost,
            tollCost: max(tollCost, 0),
            extraCosts: max(extraCosts, 0),
            totalRoadCost: total,
            estimatedTravelHours: durationHours,
            routeSource: routeSource
        )
    }

    private static func flightEstimateWithApiData(
        originState: String,
        destinationState: String,
        eventDate: Date,
        returnDate: Date,
        roadDistanceKm: Double
    ) async -> FlightEstimate? {
        let originUF = normalizeState(originState)
        let destinationUF = normalizeState(destinationState)
        guard originUF != destinationUF else { return nil }

        guard let originAirport = airportsByState[originUF]?.first,
              let destinationAirport = airportsByState[destinationUF]?.first
        else { return nil }

        let prices = await RealTimeLogisticsResolver.resolveFlightPrices(
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            eventDate: eventDate,
            returnDate: returnDate
        ) {
            // Fallback to local calculation if API fails
            let daysToEvent = max(Calendar.current.dateComponents([.day], from: Date(), to: eventDate).day ?? 0, 0)
            let stayDays = max(Calendar.current.dateComponents([.day], from: eventDate, to: returnDate).day ?? 1, 1)

            var oneWay = 180 + (roadDistanceKm * 0.22)

            if daysToEvent <= 7 {
                oneWay *= 1.60
            } else if daysToEvent <= 15 {
                oneWay *= 1.30
            } else if daysToEvent <= 30 {
                oneWay *= 1.15
            }

            if stayDays <= 1 {
                oneWay *= 1.08
            }

            let weekendBoost = isWeekend(eventDate) || isWeekend(returnDate) ? 1.12 : 1.0
            oneWay *= weekendBoost

            return (oneWay, oneWay * 2)
        }

        let roundTrip = prices.roundTripPrice
        let baggageAndTransfers: Double = 120 + (roadDistanceKm > 1200 ? 90 : 50)
        let total = roundTrip + baggageAndTransfers

        return FlightEstimate(
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            oneWayFare: prices.oneWayPrice,
            roundTripFare: roundTrip,
            baggageAndTransfers: baggageAndTransfers,
            totalAirCost: total,
            pricingSource: prices.source
        )
    }
}
