import Foundation

struct AirportOption: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let city: String
    let state: String
}

struct FlightEstimate {
    let originAirport: AirportOption
    let destinationAirport: AirportOption
    let oneWayFare: Double
    let roundTripFare: Double
    let baggageAndTransfers: Double
    let totalAirCost: Double
    let pricingSource: LogisticsDataSource
}

struct RoadEstimate {
    let distanceKm: Double
    let fuelLiters: Double
    let fuelCost: Double
    let tollCost: Double
    let extraCosts: Double
    let totalRoadCost: Double
    let estimatedTravelHours: Double
    let routeSource: LogisticsDataSource
}

struct LogisticsEstimate {
    let road: RoadEstimate
    let flight: FlightEstimate?
    let recommendedMode: String
    let recommendationReason: String
}

enum ArtistLogisticsEstimator {
    static func estimate(
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
    ) -> LogisticsEstimate {
        let road = roadEstimate(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState,
            vehicleKmPerLiter: vehicleKmPerLiter,
            fuelPricePerLiter: fuelPricePerLiter,
            tollCost: tollCost,
            extraCosts: extraRoadCosts
        )

        let flight = flightEstimate(
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

    static func airportOptions(for state: String) -> [AirportOption] {
        let normalized = normalizeState(state)
        return airportsByState[normalized] ?? []
    }

    private static func roadEstimate(
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String,
        vehicleKmPerLiter: Double,
        fuelPricePerLiter: Double,
        tollCost: Double,
        extraCosts: Double
    ) -> RoadEstimate {
        let distance = estimatedRoadDistanceKm(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState
        )

        let kmPerLiter = max(vehicleKmPerLiter, 1)
        let liters = distance / kmPerLiter
        let fuelCost = liters * max(fuelPricePerLiter, 0)
        let total = fuelCost + max(tollCost, 0) + max(extraCosts, 0)
        let travelHours = distance / 75.0

        return RoadEstimate(
            distanceKm: distance,
            fuelLiters: liters,
            fuelCost: fuelCost,
            tollCost: max(tollCost, 0),
            extraCosts: max(extraCosts, 0),
            totalRoadCost: total,
            estimatedTravelHours: travelHours,
            routeSource: .fallback
        )
    }

    private static func flightEstimate(
        originState: String,
        destinationState: String,
        eventDate: Date,
        returnDate: Date,
        roadDistanceKm: Double
    ) -> FlightEstimate? {
        let originUF = normalizeState(originState)
        let destinationUF = normalizeState(destinationState)
        guard originUF != destinationUF else { return nil }

        guard let originAirport = airportsByState[originUF]?.first,
              let destinationAirport = airportsByState[destinationUF]?.first
        else { return nil }

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

        let roundTrip = oneWay * 2
        let baggageAndTransfers: Double = 120 + (roadDistanceKm > 1200 ? 90 : 50)
        let total = roundTrip + baggageAndTransfers

        return FlightEstimate(
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            oneWayFare: oneWay,
            roundTripFare: roundTrip,
            baggageAndTransfers: baggageAndTransfers,
            totalAirCost: total,
            pricingSource: .fallback
        )
    }

    static func estimatedRoadDistanceKm(
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String
    ) -> Double {
        let originUF = normalizeState(originState)
        let destinationUF = normalizeState(destinationState)

        if originUF == destinationUF {
            if originCity.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(destinationCity.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
                return 25
            }
            return 180
        }

        guard let origin = stateCentroids[originUF], let destination = stateCentroids[destinationUF] else {
            return 850
        }

        let straight = haversineKm(lat1: origin.0, lon1: origin.1, lat2: destination.0, lon2: destination.1)
        return max(120, straight * 1.23)
    }

    static func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }

    static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    static func normalizeState(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static let airportsByState: [String: [AirportOption]] = [
        "SP": [
            AirportOption(code: "GRU", name: "Guarulhos", city: "Sao Paulo", state: "SP"),
            AirportOption(code: "VCP", name: "Viracopos", city: "Campinas", state: "SP"),
        ],
        "RJ": [
            AirportOption(code: "GIG", name: "Galeao", city: "Rio de Janeiro", state: "RJ"),
            AirportOption(code: "SDU", name: "Santos Dumont", city: "Rio de Janeiro", state: "RJ"),
        ],
        "MG": [
            AirportOption(code: "CNF", name: "Confins", city: "Belo Horizonte", state: "MG"),
        ],
        "PR": [
            AirportOption(code: "CWB", name: "Afonso Pena", city: "Curitiba", state: "PR"),
        ],
        "RS": [
            AirportOption(code: "POA", name: "Salgado Filho", city: "Porto Alegre", state: "RS"),
        ],
        "SC": [
            AirportOption(code: "FLN", name: "Hercilio Luz", city: "Florianopolis", state: "SC"),
            AirportOption(code: "NVT", name: "Navegantes", city: "Navegantes", state: "SC"),
        ],
        "BA": [
            AirportOption(code: "SSA", name: "Deputado Luis Eduardo Magalhaes", city: "Salvador", state: "BA"),
        ],
        "PE": [
            AirportOption(code: "REC", name: "Guararapes", city: "Recife", state: "PE"),
        ],
        "CE": [
            AirportOption(code: "FOR", name: "Pinto Martins", city: "Fortaleza", state: "CE"),
        ],
        "DF": [
            AirportOption(code: "BSB", name: "Brasilia", city: "Brasilia", state: "DF"),
        ],
        "GO": [
            AirportOption(code: "GYN", name: "Santa Genoveva", city: "Goiania", state: "GO"),
        ],
        "AM": [
            AirportOption(code: "MAO", name: "Eduardo Gomes", city: "Manaus", state: "AM"),
        ],
    ]

    static let stateCentroids: [String: (Double, Double)] = [
        "SP": (-22.55, -48.64),
        "RJ": (-22.90, -43.20),
        "MG": (-18.10, -44.38),
        "PR": (-24.89, -51.55),
        "RS": (-30.03, -51.23),
        "SC": (-27.24, -50.22),
        "BA": (-12.97, -38.50),
        "PE": (-8.05, -34.90),
        "CE": (-3.72, -38.54),
        "DF": (-15.79, -47.88),
        "GO": (-16.68, -49.25),
        "AM": (-3.10, -60.02),
    ]
}
