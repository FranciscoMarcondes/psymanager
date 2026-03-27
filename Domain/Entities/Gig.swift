import Foundation
import SwiftData

// MARK: - Transport Modes

enum TransportMode: String, CaseIterable, Codable {
    case car = "Carro"
    case carSharing = "Compartilhado"
    case uber = "Uber"
    case taxi = "Taxi"
    case bus = "Ônibus"
    case metro = "Metrô"
    case train = "Trem"
    case flight = "Voo"
    
    var emoji: String {
        switch self {
        case .car: return "🚗"
        case .carSharing: return "🚕"
        case .uber: return "🚙"
        case .taxi: return "🚕"
        case .bus: return "🚌"
        case .metro: return "🚇"
        case .train: return "🚂"
        case .flight: return "✈️"
        }
    }
    
    var displayName: String {
        self.rawValue
    }
}

// MARK: - Transport Leg (Part of Multi-Mode Journey)

@Model
final class TransportLeg {
    var order: Int
    var mode: TransportMode
    var fromLocation: String
    var toLocation: String
    var estimatedCost: Double
    var estimatedDurationMinutes: Int
    
    init(
        order: Int,
        mode: TransportMode,
        fromLocation: String,
        toLocation: String,
        estimatedCost: Double,
        estimatedDurationMinutes: Int
    ) {
        self.order = order
        self.mode = mode
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.estimatedCost = estimatedCost
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }
    
    var formattedDuration: String {
        let hours = estimatedDurationMinutes / 60
        let minutes = estimatedDurationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        }
        return "\(minutes)min"
    }
}

// MARK: - Logistics Scenario (One option from calculator)

@Model
final class LogisticsScenario {
    var name: String  // "Uber + Flight" | "Metro + Ônibus + Flight"
    var scenarioDescription: String
    var scenarioType: String  // "same-state", "cross-state-car", "cross-state-public"
    
    // Cost breakdown
    var roadCostToAirport: Double
    var transportToAirportMode: TransportMode
    var transportToAirportCost: Double
    
    var flightCostEstimate: Double?
    var airportParkingCost: Double?
    
    var transportFromAirportMode: TransportMode?
    var transportFromAirportCost: Double?
    
    // Multi-mode legs (if applicable)
    @Relationship(deleteRule: .cascade) var multiModeLegs: [TransportLeg] = []
    
    var createdAt: Date = Date()
    var selectedAt: Date?  // When user chose this scenario
    
    var totalCost: Double {
        roadCostToAirport + transportToAirportCost + 
        (flightCostEstimate ?? 0) + (airportParkingCost ?? 0) + 
        (transportFromAirportCost ?? 0)
    }
    
    var recommendedTag: String?  // "Melhor custo" | "Mais rápido" | "Mais confortável"

    init(
        name: String,
        scenarioDescription: String,
        scenarioType: String,
        roadCostToAirport: Double,
        transportToAirportMode: TransportMode,
        transportToAirportCost: Double,
        flightCostEstimate: Double? = nil,
        airportParkingCost: Double? = nil,
        transportFromAirportMode: TransportMode? = nil,
        transportFromAirportCost: Double? = nil,
        recommendedTag: String? = nil
    ) {
        self.name = name
        self.scenarioDescription = scenarioDescription
        self.scenarioType = scenarioType
        self.roadCostToAirport = roadCostToAirport
        self.transportToAirportMode = transportToAirportMode
        self.transportToAirportCost = transportToAirportCost
        self.flightCostEstimate = flightCostEstimate
        self.airportParkingCost = airportParkingCost
        self.transportFromAirportMode = transportFromAirportMode
        self.transportFromAirportCost = transportFromAirportCost
        self.recommendedTag = recommendedTag
    }
}

// MARK: - Main Gig Model (Refactored)

@Model
final class Gig {
    // ────── Core Information ──────
    var title: String
    var city: String
    var state: String  // 2-letter code: SP, RJ, MG, etc.
    var date: Date
    var fee: Double
    var contactName: String
    var checklistSummary: String
    
    // ────── Status Workflow ──────
    var status: String = "Lead"  // "Lead" | "Negociacao" | "Confirmado" | "Completo" | "Cancelado"
    
    // ────── Negotiation Phase ──────
    var eventAskedAboutAgency: Bool = false  // Flag when event asks
    var cacheApprovedByEvent: Double?  // Value event approved
    var cacheApprovedAt: Date?
    var negotiationNotes: String = ""
    
    // ────── Logistics Planning ──────
    var logisticsRequired: Bool = false  // Must calculate if true
    
    @Relationship(deleteRule: .cascade)
    var logisticsScenarios: [LogisticsScenario] = []  // All calculated options
    
    @Relationship(deleteRule: .noAction)
    var selectedLogisticsScenario: LogisticsScenario?  // User's choice
    
    var totalLogisticsCost: Double?  // Final agreed cost
    var logisticsUpdatedAt: Date?
    
    // ────── Transport Breakdown (for detailed logistics) ──────
    var localTransportMode: TransportMode?
    var localTransportEstimatedCost: Double?
    var transportToAirportMode: TransportMode?
    var flightCostEstimate: Double?
    var airportParkingCost: Double?
    var transportFromAirportMode: TransportMode?
    
    // ────── Confirmation & Calendar ──────
    var addedToCalendar: Bool = false
    var reminderScheduled: Bool = false
    var confirmedAt: Date?  // When moved to Confirmado

    // ────── Lifecycle ──────
    var completedAt: Date?
    var cancelledAt: Date?

    // ────── Break-even Snapshot ──────
    var breakEvenNet: Double?
    var breakEvenMarginPct: Int?
    var breakEvenStatus: String?
    var breakEvenUpdatedAt: Date?
    
    init(
        title: String,
        city: String,
        state: String,
        date: Date,
        fee: Double,
        contactName: String,
        checklistSummary: String,
        status: String = "Lead",
        addedToCalendar: Bool = false,
        reminderScheduled: Bool = false
    ) {
        self.title = title
        self.city = city
        self.state = state
        self.date = date
        self.fee = fee
        self.contactName = contactName
        self.checklistSummary = checklistSummary
        self.status = status
        self.addedToCalendar = addedToCalendar
        self.reminderScheduled = reminderScheduled
    }
    
    // ────── Helper Methods ──────
    
    var isSameState: Bool {
        // Assume DJ home state is stored elsewhere, compare with gig state
        // This will be set when comparing with a home base state
        false
    }
    
    var isNegotiating: Bool {
        status == "Negociacao"
    }
    
    var isConfirmed: Bool {
        status == "Confirmado"
    }

    var isCompleted: Bool {
        status == "Completo"
    }

    var isCancelled: Bool {
        status == "Cancelado"
    }
    
    var logisticsEstimate: String {
        if let scenario = selectedLogisticsScenario {
            return String(format: "R$ %.2f", scenario.totalCost)
        }
        return "A calcular"
    }
    
    var totalValue: Double {
        let logisticsAmount = selectedLogisticsScenario?.totalCost ?? 0
        return fee + logisticsAmount
    }
}
