import Foundation
import SwiftData

@Model
final class BreakEvenCalculation {
    var gigTitle: String
    var gigCity: String
    var gigId: String? // Referência à gig original
    
    // Inputs
    var grossFee: Double
    var agencyPercent: Double
    var taxPercent: Double
    var flight: Double
    var hotel: Double
    var transport: Double
    var food: Double
    var other: Double
    
    // Calculated results
    var netProfit: Double
    var marginPercentage: Int
    var status: String // "Lucro", "Break-even", "Prejuízo"
    
    // Metadata
    var date: Date
    var suggestedMinimumFee: Double?
    
    init(
        gigTitle: String,
        gigCity: String,
        gigId: String? = nil,
        grossFee: Double,
        agencyPercent: Double,
        taxPercent: Double,
        flight: Double,
        hotel: Double,
        transport: Double,
        food: Double,
        other: Double
    ) {
        self.gigTitle = gigTitle
        self.gigCity = gigCity
        self.gigId = gigId
        self.grossFee = grossFee
        self.agencyPercent = agencyPercent
        self.taxPercent = taxPercent
        self.flight = flight
        self.hotel = hotel
        self.transport = transport
        self.food = food
        self.other = other
        self.date = Date()
        
        // Calcular resultados
        let agencyValue = grossFee * (agencyPercent / 100)
        let taxValue = grossFee * (taxPercent / 100)
        let operationalCosts = flight + hotel + transport + food + other
        let net = grossFee - agencyValue - taxValue - operationalCosts
        
        self.netProfit = net
        self.marginPercentage = grossFee > 0 ? Int((net / grossFee) * 100) : 0
        self.status = grossFee <= 0 ? "" : net > 0 ? "Lucro" : net == 0 ? "Break-even" : "Prejuízo"
        
        // Sugerir fee mínimo se houver prejuízo
        if net < 0 {
            // Calcular fee para ter 20% de margem
            let totalCosts = agencyPercent + taxPercent
            let minFeeForBreakEven = operationalCosts / (1 - (totalCosts / 100))
            self.suggestedMinimumFee = minFeeForBreakEven * 1.20 // 20% margin
        }
    }
}
